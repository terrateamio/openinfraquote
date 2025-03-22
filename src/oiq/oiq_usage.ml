module Usage = struct
  type t = {
    hours : int option; [@default None]
    operations : int option; [@default None]
    data : int option; [@default None]
  }
  [@@deriving of_yojson]

  let hours t = t.hours
  let operations t = t.operations
  let data t = t.data
end

module Entry = struct
  type t = {
    usage : Usage.t;
    match_set : Oiq_match_set.t;
    description : string option;
  }

  let usage t = t.usage
  let match_set t = t.match_set
  let description t = t.description

  let of_yojson json =
    let module P = struct
      type match_set_entry = {
        key : string;
        value : string;
      }
      [@@deriving of_yojson]

      type t = {
        description : string option;
        match_set : match_set_entry list;
        usage : Usage.t;
      }
      [@@deriving of_yojson]
    end in
    let open CCResult.Infix in
    P.of_yojson json
    >>= fun { P.description; match_set; usage } ->
    let match_set =
      Oiq_match_set.of_list @@ CCList.map (fun { P.key; value } -> (key, value)) match_set
    in
    Ok { description; match_set; usage }
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

let match_ resource t =
  let resource_ms = Oiq_tf.Resource.to_match_set resource in
  CCList.find_opt
    (fun { Entry.match_set; _ } -> Oiq_match_set.subset ~super:resource_ms match_set)
    t.entries
