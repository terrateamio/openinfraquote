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

  let of_yojson data = { data }
  let to_match_set t = raise (Failure "NYI")
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
      CCList.map Resource.of_yojson resources @ CCList.flat_map load_resources child_modules
  | Error msg ->
      Printf.printf "%s\n" msg;
      assert false

module Plan = struct
  type t = { resources : Resource.t list }

  let of_yojson json =
    let module J = struct
      type root_module = { root_module : Yojson.Safe.t } [@@deriving of_yojson { strict = false }]
      type t = { planned_values : root_module } [@@deriving of_yojson { strict = false }]
    end in
    match J.of_yojson json with
    | Ok { J.planned_values = { J.root_module } } -> Ok { resources = load_resources root_module }
    | Error msg ->
        Printf.printf "%s\n" msg;
        assert false

  let resources t = t.resources
end

module State = struct
  type t = { resources : Resource.t list }

  let of_yojson json =
    let module J = struct
      type root_module = { root_module : Yojson.Safe.t } [@@deriving of_yojson { strict = false }]
      type t = { values : root_module } [@@deriving of_yojson { strict = false }]
    end in
    match J.of_yojson json with
    | Ok { J.values = { J.root_module } } -> Ok { resources = load_resources root_module }
    | Error msg ->
        Printf.printf "%s\n" msg;
        assert false

  let resources t = t.resources
end
