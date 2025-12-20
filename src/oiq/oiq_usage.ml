module Usage = struct
  let range_of_yojson json =
    match [%of_yojson: int] json with
    | Ok v -> Ok { Oiq_range.min = v; max = v }
    | Error _ -> [%of_yojson: int Oiq_range.t] json

  let default = { Oiq_range.min = 0; max = 0 }

  type t = {
    time : int Oiq_range.t; [@default default] [@of_yojson range_of_yojson]
    operations : int Oiq_range.t; [@default default] [@of_yojson range_of_yojson]
    data : int Oiq_range.t; [@default default] [@of_yojson range_of_yojson]
  }
  [@@deriving yojson, show]

  let time t = t.time
  let operations t = t.operations
  let data t = t.data
  let make range = { time = default; operations = default; data = range }

  (** Multiply all usage values by a factor *)
  let multiply factor t =
    {
      time = { Oiq_range.min = t.time.Oiq_range.min * factor; max = t.time.Oiq_range.max * factor };
      operations =
        { Oiq_range.min = t.operations.Oiq_range.min * factor; max = t.operations.Oiq_range.max * factor };
      data = { Oiq_range.min = t.data.Oiq_range.min * factor; max = t.data.Oiq_range.max * factor };
    }
end

(** Reference-based usage multiplier.
    Allows usage to be multiplied by a value from a referenced resource.

    For example, an ECS service's vCPU usage can be multiplied by the
    task definition's CPU value:
    {[
      {
        "ref_attr": "task_definition",
        "value_path": "values.cpu",
        "divisor": 1024
      }
    ]}

    This would multiply the base usage by (task_definition.values.cpu / 1024). *)
module Ref_multiplier = struct
  type t = {
    (** The attribute name that references another resource (e.g., "task_definition") *)
    ref_attr : string;
    (** The path within the referenced resource to get the value (e.g., "values.cpu") *)
    value_path : string;
    (** Optional divisor to apply to the value (e.g., 1024 to convert CPU units to vCPU) *)
    divisor : int; [@default 1]
  }
  [@@deriving yojson, show]

  (** Look up the multiplier value from a resource using reference info.
      Returns the multiplier value (after applying divisor), or 1 if not found. *)
  let resolve (refs : Oiq_tf.Refs.t) (resource_address : string) (t : t) : int =
    let ref_path = t.ref_attr ^ "." ^ t.value_path in
    match Oiq_tf.Refs.lookup_ref_value refs resource_address ref_path with
    | Some value_str -> (
        match CCInt.of_string value_str with
        | Some value -> CCInt.max 1 (value / t.divisor)
        | None -> 1)
    | None -> 1
end

(** Value-based usage multiplier.
    Allows usage to be multiplied by a value from the resource's own attributes.

    For example, an ECS service's usage can be multiplied by its desired_count:
    {[
      {
        "value_path": "values.desired_count",
        "divisor": 1
      }
    ]}

    This would multiply the base usage by the resource's desired_count value. *)
module Value_multiplier = struct
  type t = {
    (** The path within the resource to get the value (e.g., "values.desired_count") *)
    value_path : string;
    (** Optional divisor to apply to the value (default 1) *)
    divisor : int; [@default 1]
  }
  [@@deriving yojson, show]

  (** Look up the multiplier value from the resource's own match set.
      Returns the multiplier value (after applying divisor), or 1 if not found. *)
  let resolve (resource_ms : Oiq_match_set.t) (t : t) : int =
    match Oiq_match_set.find_by_key t.value_path resource_ms with
    | Some (_, value_str) -> (
        match CCInt.of_string value_str with
        | Some value -> CCInt.max 1 (value / t.divisor)
        | None -> 1)
    | None -> 1
end

module Entry = struct
  module P = struct
    type 'a t = {
      description : string;
      divisor : int option; [@default None]
      match_query : string;
      usage : 'a;
      ref_multiplier : Ref_multiplier.t option; [@default None]
      value_multiplier : Value_multiplier.t option; [@default None]
    }
    [@@deriving yojson]
  end

  type accessor = {
    get : Usage.t -> int Oiq_range.t;
    set : int Oiq_range.t -> Usage.t -> Usage.t;
  }

  type 'a t = {
    description : string;
    divisor : int option;
    match_query : Oiq_match_query.t;
    usage : 'a;
    ref_multiplier : Ref_multiplier.t option;
    value_multiplier : Value_multiplier.t option;
  }
  [@@deriving show]

  let make ?divisor ?ref_multiplier ?value_multiplier ~description ~match_query ~usage () =
    { description; divisor; match_query; usage; ref_multiplier; value_multiplier }

  let usage t = t.usage
  let with_usage usage t = { t with usage }
  let match_query t = t.match_query
  let description t = t.description
  let divisor t = t.divisor
  let ref_multiplier t = t.ref_multiplier
  let value_multiplier t = t.value_multiplier

  let bound_to_usage_amount accessor { Oiq_range.min; max } t =
    match accessor.get t.usage with
    | { Oiq_range.max = usage_max; _ } when usage_max < min ->
        (* The usage described in this entry does not overlap with the usage
           amount passed in. *)
        None
    | { Oiq_range.min = usage_min; max = usage_max } ->
        let diff = max - min in
        let consumption = usage_max - min in
        Some
          {
            t with
            usage =
              accessor.set
                (Oiq_range.make
                   ~min:(CCInt.max 0 (CCInt.min usage_min max - min))
                   ~max:(CCInt.min consumption diff))
                t.usage;
          }

  let time =
    { get = (fun { Usage.time; _ } -> time); set = (fun time usage -> { usage with Usage.time }) }

  let operations =
    {
      get = (fun { Usage.operations; _ } -> operations);
      set = (fun operations usage -> { usage with Usage.operations });
    }

  let data =
    { get = (fun { Usage.data; _ } -> data); set = (fun data usage -> { usage with Usage.data }) }

  let to_yojson usage_to_yojson { usage; match_query; description; divisor; ref_multiplier; value_multiplier } =
    P.to_yojson
      usage_to_yojson
      { P.description; usage; match_query = Oiq_match_query.to_string match_query; divisor; ref_multiplier; value_multiplier }

  let of_yojson usage_of_yojson json =
    let open CCResult.Infix in
    P.of_yojson usage_of_yojson json
    >>= fun { P.description; match_query; usage; divisor; ref_multiplier; value_multiplier } ->
    CCResult.map_err (fun (#Oiq_match_query.err as err) -> Oiq_match_query.show_err err)
    @@ Oiq_match_query.of_string match_query
    >>= fun match_query -> Ok { description; match_query; usage; divisor; ref_multiplier; value_multiplier }
end

type entry = {
  description : string;
  divisor : int option; [@default None]
  match_query : string;
  usage : Usage.t option; [@default None]
  ref_multiplier : Ref_multiplier.t option; [@default None]
  value_multiplier : Value_multiplier.t option; [@default None]
}
[@@deriving of_yojson]

let defaults =
  CCList.map (fun { description; divisor; match_query; usage; ref_multiplier; value_multiplier } ->
      {
        Entry.description;
        divisor;
        match_query = CCResult.get_exn @@ Oiq_match_query.of_string match_query;
        usage;
        ref_multiplier;
        value_multiplier;
      })
  @@ CCResult.get_or_failwith
  @@ [%of_yojson: entry list]
  @@ Yojson.Safe.from_string [%blob "../../files/usage.json"]

type of_channel_err = [ `Usage_file_err of string ] [@@deriving show]
type t = { entries : Usage.t option Entry.t list }

let default () = { entries = defaults }

let of_channel in_chan =
  let open CCResult.Infix in
  let json =
    try Ok (Yojson.Safe.from_channel in_chan)
    with Yojson.Json_error msg -> Error (`Usage_file_err msg)
  in
  json
  >>= fun json ->
  CCResult.map_err
    (fun msg -> `Usage_file_err msg)
    ([%of_yojson: entry list] json
    >>= fun entries ->
    CCResult.map_l
      (fun { description; divisor; match_query; usage; ref_multiplier; value_multiplier } ->
        CCResult.map_err (fun (#Oiq_match_query.err as err) -> Oiq_match_query.show_err err)
        @@ Oiq_match_query.of_string match_query
        >>= fun match_query -> Ok { Entry.description; divisor; match_query; usage; ref_multiplier; value_multiplier })
      entries
    >>= fun entries -> Ok { entries = entries @ defaults })

let match_ ms t =
  CCList.find_opt (fun { Entry.match_query; _ } -> Oiq_match_query.eval ms match_query) t.entries

let to_yojson { entries } = [%to_yojson: Usage.t option Entry.t list] entries
