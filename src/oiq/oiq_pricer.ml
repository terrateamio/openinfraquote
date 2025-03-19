(* According to ChatGPT, the cloud providers consider this a "month". *)
let hours_in_month = 730.0

type t = {
  date : string;
  monthly_total : float;
}

let price match_file =
  {
    date = Oiq_match_file.date match_file;
    monthly_total =
      CCList.fold_left
        (fun acc products ->
          assert (CCList.length products <= 1);
          CCList.fold_left
            (fun acc price ->
              match price with
              | Oiq_prices.Price.Per_hour amount -> acc +. (hours_in_month *. amount)
              | Oiq_prices.Price.Per_data _ -> acc
              | Oiq_prices.Price.Per_operation _ -> acc)
            acc
            (CCList.flat_map Oiq_prices.Product.prices products))
        0.0
        (CCList.map Oiq_match_file.Match.products (Oiq_match_file.matches match_file));
  }

let pretty_to_string t =
  Printf.sprintf "Match file date: %s\nTotal : %0.2f USD" t.date t.monthly_total
