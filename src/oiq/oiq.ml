let match_ ~pricing_root ~resource_files ~output =
  let extract_one resource_file =
    let json = Yojson.Safe.from_string @@ CCIO.with_in resource_file CCIO.read_all in
    match Oiq_tf.type_ json with
    | `Plan -> Oiq_tf.Plan.resources @@ CCResult.get_exn @@ Oiq_tf.Plan.of_yojson json
    | `State -> Oiq_tf.State.resources @@ CCResult.get_exn @@ Oiq_tf.State.of_yojson json
    | `Unknown -> raise (Failure "NYI")
  in
  let resources = CCList.flat_map extract_one resource_files in
  let res_ms_pairs = CCList.map (fun r -> (r, Oiq_tf.Resource.to_match_set r)) resources in

  (*
  CCList.iter
    (fun ms -> CCList.iter (fun mk -> Printf.printf "%s\n" mk) @@ Oiq_match_set.to_list ms)
    ms_resources;
    *)

  (*
  1. Open pricing_root and iterate across rows
  2. Read each row's match set and look for match in TF match sets
  3. Print all matching rows
  *)
  let csv_stream = Csv.of_channel @@ open_in @@ pricing_root ^ "/prices.csv" in
  let _headers = Csv.next csv_stream in

  let will_it_blend acc row =
    let p = Oiq_prices.Product.of_row row in
    let prod_ms = Oiq_prices.Product.to_match_set p in
    let price_matcher res_ms = Oiq_match_set.subset ~super:res_ms prod_ms in
    let matched_res = CCList.filter CCFun.(snd %> price_matcher) res_ms_pairs in
    let match_pairs = CCList.map (fun (r, _) -> Oiq_match_pair.make r p) matched_res in
    CCList.fold_left (fun acc mp -> Oiq_match_file.add acc mp) acc match_pairs
  in
  let match_file = Csv.fold_left ~f:will_it_blend ~init:(Oiq_match_file.make []) csv_stream in
  Printf.printf "%s\n" @@ Yojson.Safe.to_string @@ Oiq_match_file.to_yojson match_file
