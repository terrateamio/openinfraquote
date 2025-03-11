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
  let to_yojson t = to_yojson t
end
