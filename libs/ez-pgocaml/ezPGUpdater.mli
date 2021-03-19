
val main :
  ?downgrades: (int * string list) list ->
  upgrades:(int * (unit PGOCaml.t -> int -> unit)) list ->
  string ->
  unit
