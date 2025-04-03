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
    alias : string option;
  }
  [@@deriving yojson]

  let time t = t.time
  let operations t = t.operations
  let data t = t.data
  let alias t = t.alias
end

module Entry = struct
  module P = struct
    type t = {
      description : string option;
      divisor : int option; [@default None]
      match_query : string;
      usage : Usage.t option;
    }
    [@@deriving yojson]
  end

  type accessor = {
    get : Usage.t -> int Oiq_range.t;
    set : int Oiq_range.t -> Usage.t -> Usage.t;
  }

  type t = {
    description : string option;
    divisor : int option;
    match_query : Oiq_match_query.t;
    usage : Usage.t option;
  }

  let usage t = t.usage
  let match_query t = t.match_query
  let description t = t.description
  let divisor t = t.divisor

  let bound_to_usage_amount accessor { Oiq_range.min; max } t =
    CCOption.flat_map
      (fun usage ->
        match accessor.get usage with
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
                  Some
                    (accessor.set
                       (Oiq_range.make
                          ~min:(CCInt.max 0 (CCInt.min usage_min max - min))
                          ~max:(CCInt.min consumption diff))
                       usage);
              })
      t.usage

  let time =
    { get = (fun { Usage.time; _ } -> time); set = (fun time usage -> { usage with Usage.time }) }

  let operations =
    {
      get = (fun { Usage.operations; _ } -> operations);
      set = (fun operations usage -> { usage with Usage.operations });
    }

  let data =
    { get = (fun { Usage.data; _ } -> data); set = (fun data usage -> { usage with Usage.data }) }

  let to_yojson { usage; match_query; description; divisor } =
    P.to_yojson
      { P.description; usage; match_query = Oiq_match_query.to_string match_query; divisor }

  let of_yojson json =
    let open CCResult.Infix in
    P.of_yojson json
    >>= fun { P.description; match_query; usage; divisor } ->
    CCResult.map_err (fun (#Oiq_match_query.err as err) -> Oiq_match_query.show_err err)
    @@ Oiq_match_query.of_string match_query
    >>= fun match_query -> Ok { description; match_query; usage; divisor }
end

let defaults =
  CCResult.get_or_failwith
  @@ [%of_yojson: Entry.t list]
  @@ Yojson.Safe.from_string [%blob "../../files/usage.json"]

type of_channel_err = [ `Usage_file_err of string ] [@@deriving show]
type t = { entries : Entry.t list }

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
    ([%of_yojson: Entry.t list] json >>= fun entries -> Ok { entries = entries @ defaults })

let match_ ms t =
  CCList.find_opt (fun { Entry.match_query; _ } -> Oiq_match_query.eval ms match_query) t.entries

let to_yojson { entries } = [%to_yojson: Entry.t list] entries
