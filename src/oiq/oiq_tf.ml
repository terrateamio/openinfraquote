(** Detect whether JSON is a terraform plan, state, or unknown format. *)
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
    address : string;
    name : string;
    type_ : string;
    data : Yojson.Safe.t;
  }

  let address t = t.address
  let name t = t.name
  let type_ t = t.type_

  let of_yojson data =
    let module P = struct
      type t = {
        address : string;
        name : string;
        type_ : string; [@key "type"]
      }
      [@@deriving of_yojson { strict = false }]
    end in
    let open CCResult.Infix in
    P.of_yojson data >>= fun { P.address; name; type_ } -> Ok { address; name; type_; data }

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
    | `List items -> List.map (fun item -> flatten ~prefix item) items |> List.concat
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
      resources : Yojson.Safe.t list; [@default []]
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
        let module Resource_set = CCSet.Make (struct
          type t = Resource.t

          let compare r1 r2 = CCString.compare (Resource.address r1) (Resource.address r2)
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

(** [Refs] provides reference resolution for terraform plans.

    In terraform, resources can reference other resources. For example, an ECS service
    references a task definition to get memory and CPU values. This module parses the
    [configuration] block from terraform plan JSON to extract these references and
    provides functions to resolve them.

    The configuration block contains an [expressions] object for each resource that maps
    attribute names to their references:

    {[
      {
        "configuration": {
          "root_module": {
            "resources": [
              {
                "address": "aws_ecs_service.svc1",
                "expressions": {
                  "task_definition": {
                    "references": ["aws_ecs_task_definition.task1.arn", "aws_ecs_task_definition.task1"]
                  }
                }
              }
            ]
          }
        }
      }
    ]}

    Usage:
    {[
      let refs = Refs.of_yojson plan_json resources in
      match Refs.resolve_ref refs "aws_ecs_service.svc1" "task_definition" with
      | Some task_def -> Resource.to_match_set task_def
      | None -> (* no reference found *)
    ]}
*)
module Refs = struct
  module StringMap = CCMap.Make (CCString)

  type t = {
    (** Map from resource address to the resource itself *)
    resources_by_address : Resource.t StringMap.t;
    (** Map from resource address to (attribute -> list of referenced addresses) *)
    references : string list StringMap.t StringMap.t;
  }

  let empty =
    { resources_by_address = StringMap.empty; references = StringMap.empty }

  (** Parse a single resource's expressions to extract references.
      Returns a map of attribute name -> list of referenced addresses. *)
  let parse_resource_expressions (json : Yojson.Safe.t) : string list StringMap.t =
    match json with
    | `Assoc fields ->
        CCList.fold_left
          (fun acc (attr_name, expr_value) ->
            (* Look for "references" key in the expression value *)
            match expr_value with
            | `Assoc expr_fields -> (
                match CCList.assoc_opt ~eq:CCString.equal "references" expr_fields with
                | Some (`List refs) ->
                    (* Extract string references, filter to resource addresses only
                       (exclude things like "aws_ecs_task_definition.task1.arn") *)
                    let ref_addrs =
                      CCList.filter_map
                        (function
                          | `String s ->
                              (* Only keep references that look like "type.name" (2 parts)
                                 Skip things like "type.name.attribute" (3+ parts) *)
                              let parts = CCString.split_on_char '.' s in
                              if CCList.length parts = 2 then Some s else None
                          | _ -> None)
                        refs
                    in
                    if CCList.is_empty ref_addrs then acc
                    else StringMap.add attr_name ref_addrs acc
                | _ -> acc)
            | _ -> acc)
          StringMap.empty
          fields
    | _ -> StringMap.empty

  (** Recursively load configuration resources from a module and its children. *)
  let rec load_config_resources (json : Yojson.Safe.t) :
      (string * string list StringMap.t) list =
    let module P = struct
      type resource = {
        address : string;
        expressions : Yojson.Safe.t; [@default `Assoc []]
      }
      [@@deriving of_yojson { strict = false }]

      type t = {
        resources : Yojson.Safe.t list; [@default []]
        child_modules : Yojson.Safe.t list; [@default []]
      }
      [@@deriving of_yojson { strict = false }]
    end in
    match P.of_yojson json with
    | Ok { P.resources; child_modules } ->
        let this_module_refs =
          CCList.filter_map
            (fun res_json ->
              match P.resource_of_yojson res_json with
              | Ok { P.address; expressions } ->
                  let refs = parse_resource_expressions expressions in
                  if StringMap.is_empty refs then None else Some (address, refs)
              | Error _ -> None)
            resources
        in
        let child_refs =
          CCList.concat_map load_config_resources child_modules
        in
        this_module_refs @ child_refs
    | Error _ -> []

  (** Build a reference context from plan JSON and a list of resources.
      The resources should be the already-parsed resources from planned_values. *)
  let of_yojson (plan_json : Yojson.Safe.t) (resources : Resource.t list) : t =
    (* Build address -> resource map *)
    let resources_by_address =
      CCList.fold_left
        (fun acc res -> StringMap.add (Resource.address res) res acc)
        StringMap.empty
        resources
    in
    (* Parse configuration block for references *)
    let references =
      let module P = struct
        type root_module = { root_module : Yojson.Safe.t }
        [@@deriving of_yojson { strict = false }]

        type t = { configuration : root_module option [@default None] }
        [@@deriving of_yojson { strict = false }]
      end in
      match P.of_yojson plan_json with
      | Ok { P.configuration = Some { P.root_module } } ->
          let config_refs = load_config_resources root_module in
          CCList.fold_left
            (fun acc (addr, refs) -> StringMap.add addr refs acc)
            StringMap.empty
            config_refs
      | _ -> StringMap.empty
    in
    { resources_by_address; references }

  (** Build a reference context from a list of resources only (no configuration).
      This is useful for state files which don't have a configuration block. *)
  let of_resources (resources : Resource.t list) : t =
    let resources_by_address =
      CCList.fold_left
        (fun acc res -> StringMap.add (Resource.address res) res acc)
        StringMap.empty
        resources
    in
    { resources_by_address; references = StringMap.empty }

  (** Add reference entries to an existing Refs context.
      Each entry is (resource_address, attribute, list_of_referenced_addresses). *)
  let add_references (entries : (string * string * string list) list) (t : t) : t =
    let references =
      CCList.fold_left
        (fun acc (addr, attr, refs) ->
          let attr_map =
            match StringMap.find_opt addr acc with
            | Some m -> m
            | None -> StringMap.empty
          in
          let attr_map = StringMap.add attr refs attr_map in
          StringMap.add addr attr_map acc)
        t.references
        entries
    in
    { t with references }

  (** Look up a resource by its address. *)
  let find_resource (t : t) (address : string) : Resource.t option =
    StringMap.find_opt address t.resources_by_address

  (** Get the list of addresses that a resource attribute references.
      Returns None if the resource or attribute has no references. *)
  let get_references (t : t) (resource_address : string) (attribute : string) :
      string list option =
    match StringMap.find_opt resource_address t.references with
    | Some attr_map -> StringMap.find_opt attribute attr_map
    | None -> None

  (** Resolve a reference: given a resource and an attribute that references
      another resource, return the referenced resource.
      Returns the first matching resource if multiple are referenced. *)
  let resolve_ref (t : t) (resource_address : string) (attribute : string) :
      Resource.t option =
    match get_references t resource_address attribute with
    | Some (ref_addr :: _) -> find_resource t ref_addr
    | _ -> None

  (** Look up a value from a referenced resource.
      [ref_path] is a dot-separated path like "task_definition.values.memory".
      The first component is the attribute name that contains the reference,
      the remaining components are the path within the referenced resource's data.

      Example: [lookup_ref_value refs "aws_ecs_service.svc1" "task_definition.values.memory"]
      would follow the task_definition reference and return the memory value. *)
  let lookup_ref_value (t : t) (resource_address : string) (ref_path : string) :
      string option =
    match CCString.split_on_char '.' ref_path with
    | [] -> None
    | [ _ ] -> None (* Need at least "ref_attr.value_path" *)
    | ref_attr :: value_path -> (
        match resolve_ref t resource_address ref_attr with
        | None -> None
        | Some ref_resource ->
            (* Look up the value path in the referenced resource's match set *)
            let ms = Resource.to_match_set ref_resource in
            let key = CCString.concat "." value_path in
            CCOption.map snd @@ Oiq_match_set.find_by_key key ms)

  (** Get all resources in the reference context. *)
  let all_resources (t : t) : Resource.t list =
    CCList.map snd @@ StringMap.to_list t.resources_by_address
end
