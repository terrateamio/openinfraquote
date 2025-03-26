type t [@@deriving yojson, eq, ord]
type of_list_err = [ `Error ] [@@deriving show]
type of_string_err = [ `Error ] [@@deriving show]

val of_list : (string * string) list -> t
val of_string : string -> (t, [> of_string_err ]) result
val to_list : t -> (string * string) list
val subset : super:t -> t -> bool
val equal : t -> t -> bool
val find_by_key : string -> t -> (string * string) option

(** Creates a match set that contains all elements. Note that if one match set contains [foo=bar]
    and the other [foo=baz], only one will be represented in the result and it is not specified
    which. *)
val union : t -> t -> t

(** Performs a query against [super]. [query ~super query] returns [false] if all keys in [query]
    exiist in [super] but not all values match. Otherwise returns [true]. *)
val query : super:t -> t -> bool
