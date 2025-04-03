type pos = {
  lnum : int;
  offset : int;
}
[@@deriving show]

type err = [ `Match_query_parse_err of pos option * string * string ] [@@deriving show]
type t [@@deriving show]

val eval : Oiq_match_set.t -> t -> bool
val of_string : string -> (t, [> err ]) result
val to_string : t -> string
