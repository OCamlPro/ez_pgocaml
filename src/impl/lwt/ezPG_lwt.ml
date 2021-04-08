module PGOCaml = PGOCaml_generic.Make(Thread)

module Pool = struct

  let pool = ref (None : PGOCaml.pa_pg_data PGOCaml.t Lwt_pool.t option)

  let init ?(n=20) ?host ?port ?user ?password ?database ?unix_domain_socket_dir () =
    pool := Some (
        Lwt_pool.create n
          ~check:(fun _conn ok -> ok false)
          ~validate:PGOCaml.alive
          ~dispose:PGOCaml.close @@
        PGOCaml.connect ?host ?port ?user ?password ?database ?unix_domain_socket_dir)

  let use f = match !pool with
    | None -> failwith "database pool not initialised"
    | Some pool -> Lwt_pool.use pool f
end
