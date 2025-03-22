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
  type t = {
    name : string;
    type_ : string;
    data : Yojson.Safe.t;
  }

  let name t = t.name
  let type_ t = t.type_

  let of_yojson data =
    let module P = struct
      type t = {
        name : string;
        type_ : string; [@key "type"]
      }
      [@@deriving of_yojson { strict = false }]
    end in
    let open CCResult.Infix in
    P.of_yojson data >>= fun { P.name; type_ } -> Ok { name; type_; data }

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

  let to_match_set t = Oiq_match_set.of_list @@ flatten t.data
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
  type change =
    [ `Noop
    | `Add
    | `Remove
    ]

  type err = [ `Invalid_plan of string ] [@@deriving show]
  type t = { resources : (Resource.t * change) list }

  let of_yojson json =
    let module P = struct
      type root_module = { root_module : Yojson.Safe.t } [@@deriving of_yojson { strict = false }]
      type values = { values : root_module } [@@deriving of_yojson { strict = false }]

      type t = {
        prior_state : values option; [@default None]
        planned_values : root_module;
      }
      [@@deriving of_yojson { strict = false }]
    end in
    match P.of_yojson json with
    | Ok { P.prior_state; planned_values = { P.root_module = planned_values } } ->
        let open CCResult.Infix in
        let prior_state =
          CCOption.map_or
            ~default:(`Assoc [ ("resources", `List []) ])
            (fun { P.values = { P.root_module = prior_state } } -> prior_state)
            prior_state
        in
        CCResult.map_err
          (fun msg -> `Invalid_plan msg)
          ((fun prior_state planned_values -> (prior_state, planned_values))
          <$> load_resources prior_state
          <*> load_resources planned_values)
        >>= fun (prior_state, planned_values) ->
        let module String_tuple = struct
          type t = string * string [@@deriving ord]
        end in
        let module Resource_set = CCSet.Make (struct
          type t = Resource.t

          let compare r1 r2 =
            String_tuple.compare
              (Resource.name r1, Resource.type_ r1)
              (Resource.name r2, Resource.type_ r2)
        end) in
        let prior_state = Resource_set.of_list prior_state in
        let planned_values = Resource_set.of_list planned_values in
        let noop = Resource_set.inter prior_state planned_values in
        let removed = Resource_set.diff prior_state planned_values in
        let added = Resource_set.diff planned_values prior_state in
        let with_change c rs = CCList.map (fun r -> (r, c)) @@ Resource_set.to_list rs in
        let resources =
          with_change `Noop noop @ with_change `Add added @ with_change `Remove removed
        in
        Ok { resources }
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
