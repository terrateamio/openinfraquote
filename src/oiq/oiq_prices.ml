module Price = struct
  module P = struct
    type t = {
      price : float;
      type_ : string; [@key "type"]
    }
    [@@deriving yojson]
  end

  type t =
    | Per_hour of float
    | Per_operation of float
    | Per_data of float
  [@@deriving eq]

  let to_yojson = function
    | Per_hour price -> P.to_yojson { P.price; type_ = "h" }
    | Per_operation price -> P.to_yojson { P.price; type_ = "o" }
    | Per_data price -> P.to_yojson { P.price; type_ = "d" }

  let of_yojson json =
    let open CCResult.Infix in
    [%of_yojson: P.t] json
    >>= function
    | { P.price; type_ = "h" } -> Ok (Per_hour price)
    | { P.price; type_ = "o" } -> Ok (Per_operation price)
    | { P.price; type_ = "d" } -> Ok (Per_data price)
    | { P.type_; _ } -> Error ("Unknown type: " ^ type_)
end

module Product = struct
  type of_row_err =
    [ `Invalid_row_err of string list
    | `Invalid_price_err of string
    | `Invalid_match_set_err of string
    | `Invalid_pricing_match_set_err of string
    | `Invalid_price_type_err of string
    | `Empty_match_set_err
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
    | [ _service; _product_family; ""; _pricing_match_set; _price; _price_type ] ->
        Error `Empty_match_set_err
    | [ service; product_family; match_set; pricing_match_set; price; price_type ] ->
        let open CCResult.Infix in
        CCResult.map_err
          (CCFun.const (`Invalid_price_err price))
          (CCResult.of_opt (CCFloat.of_string_opt price))
        >>= fun price ->
        (match price_type with
        | "h" -> Ok (Price.Per_hour price)
        | "o" -> Ok (Price.Per_operation price)
        | "d" -> Ok (Price.Per_data price)
        | any -> Error (`Invalid_price_type_err any))
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

  let pricing_match_set t = t.pricing_match_set
  let to_match_set t = t.match_set
  let price t = t.price_info
end
