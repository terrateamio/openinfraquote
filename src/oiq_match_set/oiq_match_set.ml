module String_set = CCSet.Make (CCString)

module Ms = CCSet.Make (struct
  type t = string * string [@@deriving ord]
end)

module Mm = CCMap.Make (CCString)

let pp fmt v =
  let module P = struct
    type t = (string * string) list [@@deriving show]
  end in
  P.pp fmt @@ Ms.to_list v

type t = (Ms.t[@printer pp]) [@@deriving eq, show, ord]
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

let to_yojson =
  CCFun.(
    to_list %> CCList.map (fun (k, v) -> k ^ "=" ^ v) %> CCString.concat "&" %> [%to_yojson: string])

let of_yojson json =
  let open CCResult.Infix in
  [%of_yojson: string] json >>= fun s -> CCResult.map_err (fun _ -> "Error") @@ of_string s
