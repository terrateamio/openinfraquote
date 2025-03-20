type t = {
  date : string;
  monthly_total : float;
}

let hours = CCFun.(Oiq_usage.Usage.hours %> CCOption.get_or ~default:0 %> CCFloat.of_int)
let operations = CCFun.(Oiq_usage.Usage.operations %> CCOption.get_or ~default:0 %> CCFloat.of_int)
let data = CCFun.(Oiq_usage.Usage.data %> CCOption.get_or ~default:0 %> CCFloat.of_int)

let price_products usage products =
  CCList.fold_left
    (fun acc price ->
      match price with
      | Oiq_prices.Price.Per_hour amount -> acc +. (hours usage *. amount)
      | Oiq_prices.Price.Per_data amount -> acc +. (data usage *. amount)
      | Oiq_prices.Price.Per_operation amount -> acc +. (operations usage *. amount))
    0.0
    (CCList.flat_map Oiq_prices.Product.prices products)

let price ~usage match_file =
  {
    date = Oiq_match_file.date match_file;
    monthly_total =
      CCList.fold_left
        (fun acc match_ ->
          let resource = Oiq_match_file.Match.resource match_ in
          match Oiq_usage.match_ resource usage with
          | Some entry ->
              acc
              +. (price_products (Oiq_usage.Entry.usage entry)
                 @@ Oiq_match_file.Match.products match_)
          | None when CCList.is_empty (Oiq_match_file.Match.products match_) -> acc
          | None ->
              Logs.err (fun m -> m "No usage entry found for a resource with matching products");
              Logs.err (fun m -> m "Resource:");
              Logs.err (fun m ->
                  m "%s" (Yojson.Safe.pretty_to_string (Oiq_tf.Resource.to_yojson resource)));
              assert false)
        0.0
        (Oiq_match_file.matches match_file);
  }

let pretty_to_string t =
  Printf.sprintf "Match file date: %s\nTotal : %0.2f USD" t.date t.monthly_total
