
val main :
  ?search_path: string list ->
  string ->
  ?downgrades: (int * string list) list ->
  upgrades:(int * (unit PGOCaml.t -> int -> unit)) list ->
  unit
