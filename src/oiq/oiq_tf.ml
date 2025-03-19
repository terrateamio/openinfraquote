let type_ json =
  let module Plan = struct
    type t = {
      terraform_version : string;
      planned_values : Yojson.Safe.t;
    }
    [@@deriving of_yojson { strict = false }]
  end in
  let module State = struct
    type t = {
      terraform_version : string;
      values : Yojson.Safe.t;
    }
    [@@deriving of_yojson { strict = false }]
  end in
  match (Plan.of_yojson json, State.of_yojson json) with
  | Ok _, Ok _ -> `Unknown
  | Ok _, _ -> `Plan
  | _, Ok _ -> `State
  | _ -> `Unknown

module Resource = struct
  type t = { data : Yojson.Safe.t }

  let of_yojson data = Ok { data }
  let to_yojson t = t.data

  let rec flatten ?(prefix = "") (json : Yojson.Safe.t) : (string * string) list =
    match json with
    | `Assoc fields ->
        List.fold_left
          (fun acc (key, value) ->
            let new_prefix = if prefix = "" then key else prefix ^ "." ^ key in
            let flattened = flatten ~prefix:new_prefix value in
            acc @ flattened)
          []
          fields
    | `List items ->
        List.mapi
          (fun idx item ->
            let new_prefix = prefix ^ "." ^ string_of_int idx in
            flatten ~prefix:new_prefix item)
          items
        |> List.concat
    | `String s -> [ (prefix, s) ]
    | `Int i -> [ (prefix, string_of_int i) ]
    | `Float f -> [ (prefix, string_of_float f) ]
    | `Bool b -> [ (prefix, string_of_bool b) ]
    | `Null -> [ (prefix, "null") ]
    | `Intlit s -> [ (prefix, s) ]
    | `Tuple items ->
        List.mapi
          (fun idx item ->
            let new_prefix =
              if prefix = "" then string_of_int idx else prefix ^ "." ^ string_of_int idx
            in
            flatten ~prefix:new_prefix item)
          items
        |> List.concat
    | `Variant (name, Some content) ->
        let new_prefix = if prefix = "" then name else prefix ^ "." ^ name in
        flatten ~prefix:new_prefix content
    | `Variant (name, None) -> [ (prefix ^ "." ^ name, "") ]

  let to_match_set t =
    CCResult.get_exn @@ Oiq_match_set.of_list @@ Oiq_match_set.to_keys @@ flatten t.data
end

let rec load_resources json =
  let module P = struct
    type t = {
      resources : Yojson.Safe.t list;
      child_modules : Yojson.Safe.t list; [@default []]
    }
    [@@deriving of_yojson { strict = false }]
  end in
  match P.of_yojson json with
  | Ok { P.resources; child_modules } ->
      let open CCResult.Infix in
      CCResult.map_l load_resources child_modules
      >>= fun child_resources ->
      CCResult.map_l Resource.of_yojson resources
      >>= fun resources -> Ok (resources @ CCList.flatten child_resources)
  | Error msg -> Error msg

module Plan = struct
  type err = [ `Invalid_plan of string ] [@@deriving show]
  type t = { resources : Resource.t list }

  let of_yojson json =
    let module J = struct
      type root_module = { root_module : Yojson.Safe.t } [@@deriving of_yojson { strict = false }]
      type t = { planned_values : root_module } [@@deriving of_yojson { strict = false }]
    end in
    match J.of_yojson json with
    | Ok { J.planned_values = { J.root_module } } ->
        let open CCResult.Infix in
        CCResult.map_err (fun msg -> `Invalid_plan msg) (load_resources root_module)
        >>= fun resources -> Ok { resources }
    | Error msg -> Error (`Invalid_plan msg)

  let resources t = t.resources
end

module State = struct
  type err = [ `Invalid_state of string ] [@@deriving show]
  type t = { resources : Resource.t list }

  let of_yojson json =
    let module J = struct
      type root_module = { root_module : Yojson.Safe.t } [@@deriving of_yojson { strict = false }]
      type t = { values : root_module } [@@deriving of_yojson { strict = false }]
    end in
    match J.of_yojson json with
    | Ok { J.values = { J.root_module } } ->
        let open CCResult.Infix in
        CCResult.map_err (fun msg -> `Invalid_state msg) (load_resources root_module)
        >>= fun resources -> Ok { resources }
    | Error msg -> Error (`Invalid_state msg)

  let resources t = t.resources
end
