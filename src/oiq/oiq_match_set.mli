type t [@@deriving yojson, eq]
type of_list_err = [ `Error ] [@@deriving show]
type of_string_err = [ `Error ] [@@deriving show]

val of_list : (string * string) list -> t
val of_string : string -> (t, [> of_string_err ]) result
val to_list : t -> (string * string) list
val subset : super:t -> t -> bool

(** Creates a match set that contains all elements. Note that if one match set contains [foo=bar]
    and the other [foo=baz], only one will be represented in the result and it is not specified
    which. *)
val union : t -> t -> t

(** Performs a query against [super]. [query ~super query] returns [true] if any keys that [super]
    contains that [query] also contains match or if [super] and [query] contain no overlapping keys.
    Otherwise returns [false] *)
val query : super:t -> t -> bool
