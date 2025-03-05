module String_set = CCSet.Make (CCString)

type t = String_set.t
type of_list_err = [ `Error ] [@@deriving show]
type of_string_err = [ `Error ] [@@deriving show]

let of_list l = Ok (String_set.of_list l)

let of_string s =
  let keys = CCString.split_on_char '&' s in
  of_list keys

let subset ~super sub = String_set.subset sub super
