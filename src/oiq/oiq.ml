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
  raise (Failure "NYI")
