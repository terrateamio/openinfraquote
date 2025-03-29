type pos = {
  lnum : int;
  offset : int;
}
[@@deriving show]

type err = [ `Error of pos option * string * string ] [@@deriving show]
type t [@@deriving show]

val eval : Oiq_match_set.t -> t -> bool
val of_string : string -> (t, [> err ]) result
val to_string : t -> string
