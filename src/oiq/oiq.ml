type match_err =
  [ `Product_parse_err of Oiq_prices.Product.of_row_err
  | `Invalid_resource_file_err of string
  | Oiq_tf.Plan.err
  | Oiq_tf.State.err
  ]
[@@deriving show]

exception Match_err of match_err

let match_ ~pricing_root ~resource_files ~output =
  let open CCResult.Infix in
  let extract_one resource_file =
    try
      let json = Yojson.Safe.from_string @@ CCIO.with_in resource_file CCIO.read_all in
      match Oiq_tf.type_ json with
      | `Plan -> Oiq_tf.Plan.of_yojson json >|= Oiq_tf.Plan.resources
      | `State -> Oiq_tf.State.of_yojson json >|= Oiq_tf.State.resources
      | `Unknown -> Error (`Invalid_resource_file_err resource_file)
    with Yojson.Json_error _ -> Error (`Invalid_resource_file_err resource_file)
  in
  CCResult.map_l extract_one resource_files
  >>= fun resources ->
  let resources = CCList.flatten resources in
  let resource_price_acc =
    CCList.map (fun r -> (r, Oiq_tf.Resource.to_match_set r, [])) resources
  in
  let csv_stream = Csv.of_channel @@ open_in @@ pricing_root ^ "/prices.csv" in
  let _headers = Csv.next csv_stream in
  try
    let match_pricesheet acc row =
      match Oiq_prices.Product.of_row row with
      | Ok p ->
          let prod_ms = Oiq_prices.Product.to_match_set p in
          CCList.map
            (function
              | res, ms, acc when Oiq_match_set.subset ~super:ms prod_ms -> (res, ms, p :: acc)
              | v -> v)
            acc
      | Error err -> raise (Match_err (`Product_parse_err err))
    in
    let matches =
      CCList.map (fun (res, _, products) -> Oiq_match_file.Match.make res products)
      @@ Csv.fold_left ~f:match_pricesheet ~init:resource_price_acc csv_stream
    in
    let match_file = Oiq_match_file.make matches in
    Yojson.Safe.pretty_to_channel output @@ Oiq_match_file.to_yojson match_file;
    Ok ()
  with Match_err err -> Error err
