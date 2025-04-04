module Price = struct
  module P = struct
    type t = {
      price : float;
      type_ : string; [@key "type"]
    }
    [@@deriving yojson]
  end

  type t =
    | Per_time of float
    | Per_operation of float
    | Per_data of float
    | Attr of (string * float)
  [@@deriving eq, show]

  let to_yojson = function
    | Per_time price -> P.to_yojson { P.price; type_ = "t" }
    | Per_operation price -> P.to_yojson { P.price; type_ = "o" }
    | Per_data price -> P.to_yojson { P.price; type_ = "d" }
    | Attr (attr, price) -> P.to_yojson { P.price; type_ = "a=" ^ attr }

  let of_yojson json =
    let open CCResult.Infix in
    [%of_yojson: P.t] json
    >>= function
    | { P.price; type_ = "t" } -> Ok (Per_time price)
    | { P.price; type_ = "o" } -> Ok (Per_operation price)
    | { P.price; type_ = "d" } -> Ok (Per_data price)
    | { P.price; type_ } when CCString.prefix ~pre:"a=" type_ ->
        let attr = CCString.drop 2 type_ in
        Ok (Attr (attr, price))
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
    ccy : string;
    match_set : Oiq_match_set.t;
    price_info : Price.t;
    pricing_match_set : Oiq_match_set.t;
    product_family : string;
    service : string;
  }
  [@@deriving yojson, show, eq]

  let of_row = function
    | [ _service; _product_family; ""; _pricing_match_set; _price; _price_type; _ccy ] ->
        Error `Empty_match_set_err
    | [ service; product_family; match_set; pricing_match_set; price; price_type; ccy ] ->
        let open CCResult.Infix in
        CCResult.map_err
          (CCFun.const (`Invalid_price_err price))
          (CCResult.of_opt (CCFloat.of_string_opt price))
        >>= fun price ->
        (match price_type with
        | "t" -> Ok (Price.Per_time price)
        | "o" -> Ok (Price.Per_operation price)
        | "d" -> Ok (Price.Per_data price)
        | attr when CCString.prefix ~pre:"a=" attr -> Ok (Price.Attr (CCString.drop 2 attr, price))
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
        Ok { service; product_family; match_set; pricing_match_set; price_info; ccy }
    | row -> Error (`Invalid_row_err row)

  let pricing_match_set t = t.pricing_match_set
  let to_match_set t = t.match_set
  let price t = t.price_info
end
