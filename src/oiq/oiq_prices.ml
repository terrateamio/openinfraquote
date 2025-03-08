module Product = struct
  type t = {
    service : string;
    product_family : string;
    match_set_str : string;
    price_info : string;
  }

  let of_row row =
    match row with
    | [ service; product_family; match_set_str; price_info ] ->
        { service; product_family; match_set_str; price_info }
    | _ -> raise (Failure "NYI")

  let to_match_str t = t.match_set_str
  let to_match_set t = raise (Failure "NYI")
  let to_price_json t = raise (Failure "NYI")
end
