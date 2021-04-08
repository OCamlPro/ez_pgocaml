module type E = sig type err val from_exn : exn -> err end

module Make(E : E) = struct

  type 'a t = ('a, E.err) Result.t Lwt.t
  let (>>=) p f = Lwt.bind p (function Error e -> Lwt.return_error e | Ok x -> f x)
  let fail exn = Lwt.return_error (E.from_exn exn)
  let catch = Lwt.catch
  let return = Lwt.return_ok

  type in_channel = Lwt_io.input_channel
  type out_channel = Lwt_io.output_channel

  let open_connection sockaddr =
    let sock = Lwt_unix.socket (Unix.domain_of_sockaddr sockaddr) Lwt_unix.SOCK_STREAM 0 in
    catch
      (fun () ->
         Lwt.bind (Lwt_unix.connect sock sockaddr)
           (fun () ->
              Lwt_unix.set_close_on_exec sock;
              return (Lwt_io.of_fd ~mode:Lwt_io.input sock,
                      Lwt_io.of_fd ~mode:Lwt_io.output sock)))
      (fun exn -> Lwt.bind (Lwt_unix.close sock) (fun () -> fail exn))

  let output_char oc c = Lwt.bind (Lwt_io.write_char oc c) Lwt.return_ok
  let output_string oc s = Lwt.bind (Lwt_io.write oc s) Lwt.return_ok
  let flush oc = Lwt.bind (Lwt_io.flush oc) Lwt.return_ok
  let input_char ic = Lwt.bind (Lwt_io.read_char ic) Lwt.return_ok
  let really_input ic b n m = Lwt.bind (Lwt_io.read_into_exactly ic b n m) Lwt.return_ok
  let close_in ic = Lwt.bind (Lwt_io.close ic) Lwt.return_ok

  let output_binary_int oc n =
    output_char oc (Char.chr (n lsr 24)) >>= fun () ->
    output_char oc (Char.chr ((n lsr 16) land 255)) >>= fun () ->
    output_char oc (Char.chr ((n lsr 8) land 255)) >>= fun () ->
    output_char oc (Char.chr (n land 255))

  let input_binary_int ic =
    input_char ic >>= fun a ->
    input_char ic >>= fun b ->
    input_char ic >>= fun c ->
    input_char ic >>= fun d ->
    return ((Char.code a lsl 24)
            lor (Char.code b lsl 16)
            lor (Char.code c lsl 8)
            lor (Char.code d))
end
