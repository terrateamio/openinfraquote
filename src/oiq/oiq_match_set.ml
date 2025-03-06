module String_set = CCSet.Make (CCString)

type t = String_set.t
type of_list_err = [ `Error ] [@@deriving show]
type of_string_err = [ `Error ] [@@deriving show]

let of_list l = Ok (String_set.of_list l)

let of_string s =
  let keys = Uri.pct_decode s |> CCString.split_on_char '&' in
  of_list keys

let to_keys params =
  let encode_param (key, value) =
    let encode s = Uri.pct_encode s in
    encode key ^ "=" ^ encode value
  in
  params |> List.map encode_param

let subset ~super sub = String_set.subset sub super
