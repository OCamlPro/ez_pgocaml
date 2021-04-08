
module Make(E : Thread.E) = struct
  module PGOCaml = PGOCaml_generic.Make(Thread.Make(E))

  module Pool = struct

    let pool = ref (None : (PGOCaml.pa_pg_data PGOCaml.t, E.err) Result.t Lwt_pool.t option)

    let init ?(n=20) ?host ?port ?user ?password ?database ?unix_domain_socket_dir () =
      let validate = function
        | Result.Error _ -> Lwt.return false
        | Ok conn ->
          Lwt.map (function Result.Error _ -> false | Ok b -> b) (PGOCaml.alive conn) in
      let check conn is_ok =
        match conn with
        | Result.Error _ -> is_ok false
        | Ok conn ->
          Lwt.async (fun () ->
              Lwt.bind (PGOCaml.alive conn) (function
                  | Error _ -> is_ok false; Lwt.return_unit
                  | Ok b -> is_ok b; Lwt.return_unit)) in
      let dispose = function
        | Result.Error _ -> Lwt.return_unit
        | Ok conn -> Lwt.map (function Ok () -> () | Error _ -> ()) (PGOCaml.close conn) in
      pool := Some (
          Lwt_pool.create n ~check ~validate ~dispose @@
          PGOCaml.connect ?host ?port ?user ?password ?database ?unix_domain_socket_dir)

    let use f = match !pool with
      | None -> Lwt.return_error (E.from_exn @@ Failure "database pool not initialised")
      | Some pool -> Lwt_pool.use pool (function Error e -> Lwt.return_error e | Ok dbh -> f dbh)
  end
end
