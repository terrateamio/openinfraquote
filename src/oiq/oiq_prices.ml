module Price = struct
  module P = struct
    type t = {
      usd : string; [@key "USD"]
      unit : string;
    }
    [@@deriving yojson { strict = false }]
  end

  type err =
    [ `Invalid_usd_err of Yojson.Safe.t
    | `Invalid_unit_err of Yojson.Safe.t
    | `Invalid_price_err of Yojson.Safe.t * string
    ]
  [@@deriving show]

  type t =
    | Per_hour of float
    | Per_operation of float
    | Per_data of float
  [@@deriving eq]

  let to_yojson = function
    | Per_hour amount -> P.to_yojson { P.usd = CCFloat.to_string amount; unit = "Hrs" }
    | Per_operation amount -> P.to_yojson { P.usd = CCFloat.to_string amount; unit = "Op" }
    | Per_data amount -> P.to_yojson { P.usd = CCFloat.to_string amount; unit = "GB" }

  let of_row json =
    let open CCResult.Infix in
    CCResult.map_err (fun msg -> `Invalid_price_err (json, msg)) (P.of_yojson json)
    >>= function
    | {
        P.usd;
        unit =
          ( "Hrs"
          | "Hours"
          | "vCPU-hour"
          | "vCPU-Months"
          | "vCPU-Hours"
          | "ACU-Hr"
          | "ACU-hour"
          | "ACU-Months"
          | "Bucket-Mo" );
      } -> (
        match CCFloat.of_string_opt usd with
        | Some amount -> Ok (Per_hour amount)
        | None -> Error (`Invalid_usd_err json))
    | {
        P.usd;
        unit = "GB-Mo" | "MBPS-Mo" | "GB" | "Objects" | "Gigabyte Month" | "Tag-Mo" | "GB-month";
      } -> (
        match CCFloat.of_string_opt usd with
        | Some amount -> Ok (Per_data amount)
        | None -> Error (`Invalid_usd_err json))
    | {
        P.usd;
        unit =
          ( "Op"
          | "IOPS-Mo"
          | "Requests"
          | "API Requests"
          | "IOs"
          | "Jobs"
          | "Updates"
          | "CR-Hr"
          | "API Calls" );
      } -> (
        match CCFloat.of_string_opt usd with
        | Some amount -> Ok (Per_operation amount)
        | None -> Error (`Invalid_usd_err json))
    | _ -> Error (`Invalid_unit_err json)

  let of_yojson json = CCResult.map_err show_err (of_row json)
end

module Product = struct
  type of_row_err =
    [ `Invalid_price_json_err of string
    | `Invalid_row_err of string list
    | `Invalid_usd_err of Yojson.Safe.t
    | `Invalid_unit_err of Yojson.Safe.t
    | `Invalid_price_err of Yojson.Safe.t * string
    | `Invalid_match_set_err of string
    ]
  [@@deriving show]

  type t = {
    service : string;
    product_family : string;
    match_set : Oiq_match_set.t;
    price_info : Price.t list;
  }
  [@@deriving yojson, eq]

  let of_row = function
    | [ service; product_family; match_set_str; price_info ] -> (
        try
          let open CCResult.Infix in
          let json = Yojson.Safe.from_string price_info in
          let module P = struct
            type t = Price.t list [@@deriving of_yojson { strict = false }]
          end in
          CCResult.map_err (fun msg -> `Invalid_price_json_err msg) (P.of_yojson json)
          >>= fun price_info ->
          CCResult.map_err
            (fun _ -> `Invalid_match_set_err match_set_str)
            (Oiq_match_set.of_string match_set_str)
          >>= fun match_set -> Ok { service; product_family; match_set; price_info }
        with Yojson.Json_error msg -> Error (`Invalid_price_json_err msg))
    | row -> Error (`Invalid_row_err row)

  let to_match_set t = t.match_set
  let prices t = t.price_info
end
