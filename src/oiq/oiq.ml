type match_err =
  [ `Product_parse_err of Oiq_prices.Product.of_row_err
  | `Invalid_resource_file_err of string
  | Oiq_tf.Plan.err
  | Oiq_tf.State.err
  ]
[@@deriving show]

type price_err =
  [ `Invalid_match_file_err of string
  | Oiq_usage.of_channel_err
  | Oiq_pricer.price_err
  ]
[@@deriving show]

exception Match_err of match_err

(** Extract resources and reference context from a terraform file.
    Returns (resources with change type, reference context). *)
let extract_resources_and_refs resource_file =
  try
    let json = Yojson.Safe.from_string @@ CCIO.with_in resource_file CCIO.read_all in
    match Oiq_tf.type_ json with
    | `Plan -> (
        match Oiq_tf.Plan.of_yojson json with
        | Ok plan ->
            let resources = Oiq_tf.Plan.resources plan in
            let just_resources = CCList.map fst resources in
            let refs = Oiq_tf.Refs.of_yojson json just_resources in
            Ok (resources, refs)
        | Error err -> Error err)
    | `State -> (
        match Oiq_tf.State.of_yojson json with
        | Ok state ->
            let resources = Oiq_tf.State.resources state in
            let refs = Oiq_tf.Refs.of_resources resources in
            Ok (CCList.map (fun r -> (r, `Noop)) resources, refs)
        | Error err -> Error err)
    | `Unknown -> Error (`Invalid_resource_file_err resource_file)
  with Yojson.Json_error _ -> Error (`Invalid_resource_file_err resource_file)

let match_ ~pricesheet ~resource_files ~output =
  let open CCResult.Infix in
  CCResult.map_l extract_resources_and_refs resource_files
  >>= fun results ->
  (* Combine all resources and merge reference contexts *)
  let all_resources = CCList.concat_map fst results in
  let all_refs =
    (* For now, just use the first non-empty refs context.
       In the future, we could merge them. *)
    CCList.find_map
      (fun (_, refs) ->
        let resources = Oiq_tf.Refs.all_resources refs in
        if CCList.is_empty resources then None else Some refs)
      results
    |> CCOption.get_or ~default:Oiq_tf.Refs.empty
  in
  let resource_price_acc =
    CCList.map (fun (r, c) -> (r, c, Oiq_tf.Resource.to_match_set r, [])) all_resources
  in
  CCIO.with_in pricesheet (fun in_chan ->
      let csv_stream = Csv.of_channel in_chan in
      let _headers = Csv.next csv_stream in
      try
        let match_pricesheet acc row =
          match Oiq_prices.Product.of_row row with
          | Ok p ->
              let prod_ms = Oiq_prices.Product.to_match_set p in
              CCList.map
                (function
                  | res, c, ms, acc when Oiq_match_set.subset ~super:ms prod_ms ->
                      (res, c, ms, p :: acc)
                  | v -> v)
                acc
          | Error `Empty_match_set_err -> acc
          | Error err -> raise (Match_err (`Product_parse_err err))
        in
        let matches =
          CCList.map (fun (res, c, _, products) -> Oiq_match_file.Match.make res products c)
          @@ Csv.fold_left ~f:match_pricesheet ~init:resource_price_acc csv_stream
        in
        (* Build ref_info from the reference context *)
        let just_resources = CCList.map fst all_resources in
        let ref_info = Oiq_match_file.Ref_info.of_refs all_refs just_resources in
        let match_file = Oiq_match_file.make ~ref_info matches in
        Yojson.Safe.pretty_to_channel output @@ Oiq_match_file.to_yojson match_file;
        Ok ()
      with Match_err err -> Error err)

let price ?usage ?match_query ~input () =
  let open CCResult.Infix in
  let read_match_file =
    try
      let json = Yojson.Safe.from_channel input in
      CCResult.map_err (fun msg -> `Invalid_match_file_err msg) (Oiq_match_file.of_yojson json)
    with Yojson.Json_error msg -> Error (`Invalid_match_file_err msg)
  in
  CCOption.map_or ~default:(Ok (Oiq_usage.default ())) Oiq_usage.of_channel usage
  >>= fun usage ->
  read_match_file >>= fun match_file -> Oiq_pricer.price ?match_query ~usage match_file
