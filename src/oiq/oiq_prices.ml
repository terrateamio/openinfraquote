module Price = struct
  type err =
    [ `Invalid_usd_err of Yojson.Safe.t
    | `Invalid_unit_err of Yojson.Safe.t
    | `Invalid_price_err of Yojson.Safe.t * string
    ]
  [@@deriving show]

  type t =
    | Per_hour of float
    | Per_operation of float
    | Reserved of float
  [@@deriving eq]

  let to_yojson t = raise (Failure "POOP")

  let of_row json =
    let module P = struct
      type t = {
        usd : string; [@key "USD"]
        unit : string;
      }
      [@@deriving of_yojson { strict = false }]
    end in
    let open CCResult.Infix in
    CCResult.map_err (fun msg -> `Invalid_price_err (json, msg)) (P.of_yojson json)
    >>= function
    | { P.usd; unit = "hr" } -> (
        match CCFloat.of_string_opt usd with
        | Some amount -> Ok (Per_hour amount)
        | None -> Error (`Invalid_usd_err json))
    | { P.usd; unit = "op" } -> (
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
    ]
  [@@deriving show]

  type t = {
    service : string;
    product_family : string;
    match_set_str : string;
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
          >>= fun price_info -> Ok { service; product_family; match_set_str; price_info }
        with Yojson.Json_error msg -> Error (`Invalid_price_json_err msg))
    | row -> Error (`Invalid_row_err row)

  let to_match_set t = CCResult.get_exn @@ Oiq_match_set.of_string t.match_set_str
end
