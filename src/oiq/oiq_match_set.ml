module String_set = CCSet.Make (CCString)

module Ms = CCSet.Make (struct
  type t = string * string [@@deriving ord]
end)

module Mm = CCMap.Make (CCString)

type t = Ms.t [@@deriving eq, ord]
type of_list_err = [ `Error ] [@@deriving show]
type of_string_err = [ `Error ] [@@deriving show]

let of_list l = Ms.of_list l

let of_string s =
  let open CCResult.Infix in
  CCResult.map_err (fun _ -> `Error)
  @@ CCResult.map_l (fun s -> CCResult.of_opt @@ CCString.Split.left ~by:"=" s)
  @@ CCList.map Uri.pct_decode
  @@ CCList.filter CCFun.(CCString.equal "" %> not)
  @@ CCString.split_on_char '&' s
  >|= of_list

let to_list t = Ms.to_list t
let subset ~super sub = Ms.subset sub super
let union = Ms.union
let find_by_key key t = CCList.find_opt CCFun.(fst %> CCString.equal key) @@ to_list t

let query ~super query =
  let super_list = Ms.to_list super in
  let query_list = Ms.to_list query in
  let super_set = String_set.of_list @@ CCList.map fst super_list in
  let query_set = String_set.of_list @@ CCList.map fst query_list in
  if String_set.subset query_set super_set then
    (* If all keys in [query] are in [super], then try to match further.
       Otherwise return true.  This is because this function has, maybe what
       till turn out to be surprising, semantcs such that it only tries to
       perform a match if all keys exist. *)
    let super = Mm.of_list super_list in
    let query = Mm.of_list query_list in
    Mm.fold
      (fun k v acc ->
        match Mm.find_opt k super with
        | Some v' -> acc && CCString.equal v v'
        | None -> acc)
      query
      true
  else true

let to_yojson =
  CCFun.(
    to_list %> CCList.map (fun (k, v) -> k ^ "=" ^ v) %> CCString.concat "&" %> [%to_yojson: string])

let of_yojson json =
  let open CCResult.Infix in
  [%of_yojson: string] json >>= fun s -> CCResult.map_err (fun _ -> "Error") @@ of_string s
