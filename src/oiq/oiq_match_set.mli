type t [@@deriving yojson, eq]
type of_list_err = [ `Error ] [@@deriving show]
type of_string_err = [ `Error ] [@@deriving show]

val of_list : string list -> (t, [> of_list_err ]) result
val of_string : string -> (t, [> of_string_err ]) result
val to_keys : (string * string) list -> string list
val to_list : t -> string list
val subset : super:t -> t -> bool
