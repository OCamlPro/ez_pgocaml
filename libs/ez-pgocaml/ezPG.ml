exception ExecFailed of string

let connect ?host ?port ?user ?password database =
  let (dbh : 'a PGOCaml.t PGOCaml.monad) =
    PGOCaml.connect ?host ?port ?user ?password ~database ()
  in
  dbh

let close dbh =   PGOCaml.close dbh

let exec ?(verbose=true) dbh ?callback query =
  let res =
    try
      if verbose then
        Printf.eprintf "exec: %s\n%!" query;
      ignore (() = PGOCaml.prepare dbh ~query ());
      let (rows : PGOCaml.result list list) =
        PGOCaml.execute dbh ~params:[] () in
      Some rows
    with
    | exn ->
       if not verbose then
         Printf.eprintf "exec: %s\n%!" query;
       Printf.eprintf "EzPG error: %s\n%!"
                      (Printexc.to_string exn);
       match callback with
       | None -> raise (ExecFailed query)
       | Some _ -> None
  in
  match callback with
  | None -> ()
  | Some f ->
     f (match res with
        | None -> None
        | Some rows ->
           let rows =
             List.map (fun cols ->
               List.map (fun res ->
                   match res with
                   | None -> ""
                   | Some s -> s
                 ) cols
               ) rows
           in
           Some rows)

let execs ?verbose dbh queries =
  List.iter (fun query ->
      exec ?verbose dbh query) queries


let createdb ?(verbose=true) database =
  let dbh = connect "postgres" in
  Printf.kprintf (fun s -> exec ~verbose dbh s)
                 "CREATE DATABASE %s" database;
  close dbh

let dropdb ?(verbose=true) database =
  let dbh = connect "postgres" in
  Printf.kprintf (fun s -> exec ~verbose dbh s)
                 "DROP DATABASE %s" database;
  close dbh

let begin_tr dbh = exec dbh "BEGIN"
let end_tr dbh = exec dbh "COMMIT"
let abort_tr dbh = exec dbh "ABORT"

let in_tr dbh f =
  let should_abort = ref true in
  try
    begin_tr dbh;
    f dbh;
    should_abort := false;
    end_tr dbh
  with exn ->
       if !should_abort then
         abort_tr dbh;
       raise exn

let touch_witness ?witness version =
    match witness with
    | None -> ()
    | Some file ->
       let oc = open_out file in
       Printf.fprintf oc "%d\n" version;
       close_out oc

let init_version0 dbh =
  exec dbh "CREATE SCHEMA db";
  exec dbh "SET search_path TO db,public";
  exec dbh {|
            CREATE TABLE info (name VARCHAR PRIMARY KEY, value INTEGER)
            |};
  exec dbh {|
            INSERT INTO info VALUES ('version',0)
            |};
  ()

let set_version dbh version =
  Printf.kprintf (fun s -> exec dbh s)
                 "UPDATE info SET value = %d WHERE name = 'version'" version

let update_version ~target ?witness dbh version versions =
  let version = ref version in
  while !version < target do
    Printf.eprintf "version = %d\n%!" !version;
    begin
      try
        let f = List.assoc !version versions in
        begin_tr dbh;
        f dbh;
        set_version dbh (!version+1);
        end_tr dbh;
        touch_witness ?witness !version;
        version := !version +1;
      with Not_found ->
        Printf.eprintf "Your database version %d is unsupported.\n" !version;
        Printf.eprintf "Maximal supported version is %d.\n%!" target;
        Printf.eprintf "Aborting.\n%!";
        exit 2
    end;
  done;

  exec ~verbose:false dbh {|
                           SELECT value FROM info WHERE name = 'version'
                           |} ~callback:(fun res ->
         let version =
           match res with
           | Some [[ version ]] -> (try int_of_string version with _ -> -1)
           | _ -> -1
         in
         if version <> target then begin
             Printf.eprintf "Error: database update failed.\n%!";
             Printf.eprintf "  Cannot run on this database schema.\n%!";
             exit 2
           end;
         Printf.printf "EzPG: database is up-to-date at version %d\n%!"
                       target);
  ()

let update ?(verbose=false)
           ~versions
           ?(target = List.length versions) ?witness dbh =

  exec ~verbose dbh {|
            SELECT value FROM info WHERE name = 'version'
            |} ~callback:(fun res ->
         let version =
           match res with
           | Some [[ "" ]] -> 0
           | Some [[ version ]] -> int_of_string version
           | Some [] -> 0
           | Some _ -> 0
           | None -> 0
         in
         update_version ~target ?witness dbh version versions
       )
