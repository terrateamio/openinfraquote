module Price = struct
  type err =
    [ `Invalid_usd_err of Yojson.Safe.t
    | `Invalid_unit_err of Yojson.Safe.t
    | `Invalid_price_err of Yojson.Safe.t * string
    ]
  [@@deriving show]

  type t = {
    per_hour : float; [@default 0.0]
    per_operation : float; [@default 0.0]
    per_data : float; [@default 0.0]
  }
  [@@deriving eq, yojson]

  let per_hour t = t.per_hour
  let per_operation t = t.per_operation
  let per_data t = t.per_data
end

module Product = struct
  type of_row_err =
    [ `Invalid_price_json_err of string
    | `Invalid_row_err of string list
    | `Invalid_price_err
    | `Invalid_match_set_err of string
    | `Invalid_pricing_match_set_err of string
    ]
  [@@deriving show]

  type t = {
    service : string;
    product_family : string;
    match_set : Oiq_match_set.t;
    pricing_match_set : Oiq_match_set.t;
    price_info : Price.t;
  }
  [@@deriving yojson, eq]

  let of_row = function
    | [ service; product_family; match_set; pricing_match_set; per_hour; per_operation; per_data ]
      ->
        let open CCResult.Infix in
        CCResult.map_err
          (CCFun.const `Invalid_price_err)
          (CCResult.of_opt
             CCOption.Infix.(
               (fun per_hour per_operation per_data -> { Price.per_hour; per_operation; per_data })
               <$> CCFloat.of_string_opt per_hour
               <*> CCFloat.of_string_opt per_operation
               <*> CCFloat.of_string_opt per_data))
        >>= fun price_info ->
        CCResult.map_err
          (fun _ -> `Invalid_match_set_err match_set)
          (Oiq_match_set.of_string match_set)
        >>= fun match_set ->
        CCResult.map_err
          (fun _ -> `Invalid_pricing_match_set_err pricing_match_set)
          (Oiq_match_set.of_string pricing_match_set)
        >>= fun pricing_match_set ->
        Ok { service; product_family; match_set; pricing_match_set; price_info }
    | row -> Error (`Invalid_row_err row)

  let to_match_set t = t.match_set
  let price t = t.price_info
end
