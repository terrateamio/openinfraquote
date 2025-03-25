module Usage = struct
  let range_of_yojson json =
    match [%of_yojson: int] json with
    | Ok v -> Ok { Oiq_range.min = v; max = v }
    | Error _ -> [%of_yojson: int Oiq_range.t] json

  let default = { Oiq_range.min = 0; max = 0 }

  type t = {
    hours : int Oiq_range.t; [@default default] [@of_yojson range_of_yojson]
    operations : int Oiq_range.t; [@default default] [@of_yojson range_of_yojson]
    data : int Oiq_range.t; [@default default] [@of_yojson range_of_yojson]
  }
  [@@deriving yojson]

  let hours t = t.hours
  let operations t = t.operations
  let data t = t.data
end

module Entry = struct
  module P = struct
    type match_set_entry = {
      key : string;
      value : string;
    }
    [@@deriving yojson]

    type t = {
      description : string option;
      divisor : int option; [@default None]
      match_set : match_set_entry list;
      usage : Usage.t;
    }
    [@@deriving yojson]
  end

  type t = {
    description : string option;
    divisor : int option;
    match_set : Oiq_match_set.t;
    usage : Usage.t;
  }

  let usage t = t.usage
  let match_set t = t.match_set
  let description t = t.description
  let divisor t = t.divisor

  let to_yojson { usage; match_set; description; divisor } =
    P.to_yojson
      {
        P.description;
        usage;
        match_set =
          CCList.map (fun (key, value) -> { P.key; value }) @@ Oiq_match_set.to_list match_set;
        divisor;
      }

  let of_yojson json =
    let open CCResult.Infix in
    P.of_yojson json
    >>= fun { P.description; match_set; usage; divisor } ->
    let match_set =
      Oiq_match_set.of_list @@ CCList.map (fun { P.key; value } -> (key, value)) match_set
    in
    Ok { description; match_set; usage; divisor }
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
  CCList.find_opt (fun { Entry.match_set; _ } -> Oiq_match_set.subset ~super:ms match_set) t.entries
