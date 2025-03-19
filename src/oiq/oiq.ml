let match_ ~pricing_root ~resource_files ~output =
  let extract_one resource_file =
    let json = Yojson.Safe.from_string @@ CCIO.with_in resource_file CCIO.read_all in
    match Oiq_tf.type_ json with
    | `Plan -> Oiq_tf.Plan.resources @@ CCResult.get_exn @@ Oiq_tf.Plan.of_yojson json
    | `State -> Oiq_tf.State.resources @@ CCResult.get_exn @@ Oiq_tf.State.of_yojson json
    | `Unknown -> raise (Failure "NYI")
  in
  let resources = CCList.flat_map extract_one resource_files in
  let resource_price_acc =
    CCList.map (fun r -> (r, Oiq_tf.Resource.to_match_set r, [])) resources
  in
  let csv_stream = Csv.of_channel @@ open_in @@ pricing_root ^ "/prices.csv" in
  let _headers = Csv.next csv_stream in
  let match_pricesheet acc row =
    let p = Oiq_prices.Product.of_row row in
    let prod_ms = Oiq_prices.Product.to_match_set p in
    CCList.map
      (function
        | res, ms, acc when Oiq_match_set.subset ~super:ms prod_ms -> (res, ms, p :: acc)
        | v -> v)
      acc
  in
  let product_resource_matches =
    CCList.map (fun (res, _, products) -> (res, products))
    @@ Csv.fold_left ~f:match_pricesheet ~init:resource_price_acc csv_stream
  in
  let match_file = Oiq_match_file.make product_resource_matches in
  Yojson.Safe.pretty_to_channel output @@ Oiq_match_file.to_yojson match_file
