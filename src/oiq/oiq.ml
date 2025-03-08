let match_ ~pricing_root ~resource_files ~output =
  let extract_one resource_file =
    let json = Yojson.Safe.from_string @@ CCIO.with_in resource_file CCIO.read_all in
    match Oiq_tf.type_ json with
    | `Plan -> Oiq_tf.Plan.resources @@ CCResult.get_exn @@ Oiq_tf.Plan.of_yojson json
    | `State -> Oiq_tf.State.resources @@ CCResult.get_exn @@ Oiq_tf.State.of_yojson json
    | `Unknown -> raise (Failure "NYI")
  in
  let resources = CCList.flat_map extract_one resource_files in
  let match_sets = CCList.map Oiq_tf.Resource.to_match_set resources in
  CCList.iter
    (fun ms -> CCList.iter (fun mk -> Printf.printf "%s\n" mk) @@ Oiq_match_set.to_list ms)
    match_sets;
  (*
  1. Open pricing_root and iterate across rows
  2. Read each row's match set and look for match in TF match sets
  3. Print all matching rows
  *)
  (* let ic = open_in pricing_root in *)
  (* let csv_stream = Csv.of_channel ic in *)
  (* let _headers = Csv.next csv_stream in *)
  (* let fn r = *)
  (*   Oiq_prices.Product.of_row r |> Oiq_prices.Product.to_match_str |> Printf.printf "match str %s" *)
  (* in *)
  (* Csv.iter ~f:fn csv_stream; *)
  raise (Failure "WE ARE PRINTING LINES")
