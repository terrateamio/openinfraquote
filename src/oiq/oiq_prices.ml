module Product = struct
  type t = {
    service : string;
    product_family : string;
    match_set_str : string;
    price_info : string;
  }
  [@@deriving yojson, eq]

  let of_row row =
    match row with
    | [ service; product_family; match_set_str; price_info ] ->
        { service; product_family; match_set_str; price_info }
    | _ -> raise (Failure "NYI")

  let to_match_set t = CCResult.get_exn @@ Oiq_match_set.of_string t.match_set_str

  (* price_info is a json string in the CSV. we parse it before printing our json *)
  let to_yojson t =
    let price_info_json =
      try Yojson.Safe.from_string t.price_info
      with Yojson.Safe.Util.Type_error (_, _) | Yojson.Json_error _ -> `String t.price_info
    in
    `Assoc
      [
        ("service", `String t.service);
        ("product_family", `String t.product_family);
        ("match_set_str", `String t.match_set_str);
        ("price_info", price_info_json);
      ]
end
