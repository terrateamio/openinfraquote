module Price_range = struct
  type t = float Oiq_range.t [@@deriving to_yojson]
end

module Product = struct
  type t = {
    price : Price_range.t;
    product_max : Oiq_prices.Product.t;
    product_min : Oiq_prices.Product.t;
    usage : Oiq_usage.Entry.t;
  }
  [@@deriving to_yojson]
end

module Resource = struct
  let change_to_yojson = function
    | `Noop -> `String "noop"
    | `Add -> `String "add"
    | `Remove -> `String "remove"

  type t = {
    address : string;
    change : Oiq_tf.Plan.change; [@to_yojson change_to_yojson]
    name : string;
    price : Price_range.t;
    products : Product.t list;
    type_ : string; [@key "type"]
  }
  [@@deriving to_yojson]
end

type t = {
  match_date : string;
  match_query : string list;
  price : Price_range.t;
  price_date : string;
  price_diff : Price_range.t;
  resources : Resource.t list;
}
[@@deriving to_yojson]

let hours = CCFun.(Oiq_usage.Usage.hours %> CCFloat.of_int)
let operations = CCFun.(Oiq_usage.Usage.operations %> CCFloat.of_int)
let data = CCFun.(Oiq_usage.Usage.data %> CCFloat.of_int)

let price_products entry products =
  let usage = Oiq_usage.Entry.usage entry in
  let divisor = CCFloat.of_int @@ CCOption.get_or ~default:1 @@ Oiq_usage.Entry.divisor entry in
  let priced_products =
    CCList.sort (fun (_, l) (_, r) -> CCFloat.compare l r)
    @@ CCList.map
         (fun product ->
           let price = Oiq_prices.Product.price product in
           let quote =
             match price with
             | Oiq_prices.Price.Per_hour price -> hours usage /. divisor *. price
             | Oiq_prices.Price.Per_operation price -> operations usage /. divisor *. price
             | Oiq_prices.Price.Per_data price -> data usage /. divisor *. price
           in
           (product, quote))
         products
  in
  match (CCList.head_opt priced_products, CCList.head_opt @@ CCList.rev priced_products) with
  | Some min, Some max -> (min, max)
  | _, _ -> assert false

let filter_products match_query matches =
  if CCList.is_empty match_query then matches
  else
    CCList.map
      (fun match_ ->
        let resource_ms = Oiq_tf.Resource.to_match_set @@ Oiq_match_file.Match.resource match_ in
        let products =
          CCList.filter
            (fun product ->
              let ms =
                Oiq_match_set.union
                  resource_ms
                  (Oiq_match_set.union
                     (Oiq_prices.Product.pricing_match_set product)
                     (Oiq_prices.Product.to_match_set product))
              in
              CCList.exists (fun query -> Oiq_match_set.query ~super:ms query) match_query)
            (Oiq_match_file.Match.products match_)
        in
        Oiq_match_file.Match.make
          (Oiq_match_file.Match.resource match_)
          products
          (Oiq_match_file.Match.change match_))
      matches

let price ~usage ~match_query match_file =
  let priced_resources =
    let module Entry_map = CCMap.Make (struct
      type t = Oiq_usage.Entry.t

      let compare e1 e2 =
        Oiq_match_set.compare (Oiq_usage.Entry.match_set e1) (Oiq_usage.Entry.match_set e2)
    end) in
    CCList.filter_map (fun match_ ->
        let resource = Oiq_match_file.Match.resource match_ in
        let products = Oiq_match_file.Match.products match_ in
        let resource_products =
          CCList.map
            (fun product ->
              ( product,
                Oiq_match_set.union
                  (Oiq_tf.Resource.to_match_set resource)
                  (Oiq_match_set.union
                     (Oiq_prices.Product.to_match_set product)
                     (Oiq_prices.Product.pricing_match_set product)) ))
            products
        in
        let usage_entries =
          CCList.fold_left
            (fun acc (product, ms) ->
              match Oiq_usage.match_ ms usage with
              | Some entry -> Entry_map.add_to_list entry product acc
              | None -> acc)
            Entry_map.empty
            resource_products
        in
        let products =
          Entry_map.fold
            (fun entry products acc ->
              let (product_min, min), (product_max, max) = price_products entry products in
              { Product.price = { Oiq_range.min; max }; product_max; product_min; usage = entry }
              :: acc)
            usage_entries
            []
        in
        if not (CCList.is_empty products) then
          let d = if Oiq_match_file.Match.change match_ = `Remove then CCFloat.neg else CCFun.id in
          let price =
            CCList.fold_left
              (fun { Oiq_range.min; max }
                   { Product.price = { Oiq_range.min = min'; max = max' }; _ }
                 -> { Oiq_range.min = min +. min'; max = max +. max' })
              { Oiq_range.min = 0.0; max = 0.0 }
              products
          in
          Some
            {
              Resource.address = Oiq_tf.Resource.address resource;
              change = Oiq_match_file.Match.change match_;
              name = Oiq_tf.Resource.name resource;
              price = { Oiq_range.min = d price.Oiq_range.min; max = d price.Oiq_range.max };
              type_ = Oiq_tf.Resource.type_ resource;
              products;
            }
        else None)
    @@ filter_products match_query
    @@ Oiq_match_file.matches match_file
  in
  let price =
    CCList.fold_left
      (fun { Oiq_range.min; max } { Resource.price = { Oiq_range.min = min'; max = max' }; _ } ->
        { Oiq_range.min = min +. min'; max = max +. max' })
      { Oiq_range.min = 0.0; max = 0.0 }
      priced_resources
  in
  let price_diff =
    CCList.fold_left
      (fun ({ Oiq_range.min; max } as acc)
           { Resource.price = { Oiq_range.min = min'; max = max' }; change; _ }
         ->
        match change with
        | `Noop -> acc
        | `Add | `Remove -> { Oiq_range.min = min +. min'; max = max +. max' })
      { Oiq_range.min = 0.0; max = 0.0 }
      priced_resources
  in
  let match_query =
    CCList.map
      (fun query ->
        CCString.concat " & "
        @@ CCList.map (fun (k, v) -> k ^ "=" ^ v)
        @@ Oiq_match_set.to_list query)
      match_query
  in
  {
    match_date = Oiq_match_file.date match_file;
    match_query;
    price;
    price_date = ISO8601.Permissive.string_of_datetime (Unix.gettimeofday ());
    price_diff;
    resources = priced_resources;
  }

let pretty_to_string t =
  Printf.sprintf
    "Match date: %s\n\
     Price date: %s\n\
     Match query: %s\n\
     Min Price: %0.2f USD\n\
     Max Price: %0.2f USD\n\
     Min Price Diff: %0.2f USD\n\
     Max Price Diff: %0.2f USD\n\
     Resources\n\
     %50s\t%30s\t%20s\t%20s\t%10s\n\
     %s"
    t.match_date
    t.price_date
    (CCString.concat " | " t.match_query)
    t.price.Oiq_range.min
    t.price.Oiq_range.max
    t.price_diff.Oiq_range.min
    t.price_diff.Oiq_range.max
    "Name"
    "Type"
    "Min Price (USD)"
    "Max Price (USD)"
    "Change"
    (CCString.concat "\n"
    @@ CCList.map
         (fun { Resource.address; name; type_; price = { Oiq_range.min; max }; change; _ } ->
           let name =
             if not (CCString.equal address (type_ ^ "." ^ name)) then
               CCString.concat "." @@ CCList.tl @@ CCString.split_on_char '.' address
             else name
           in
           Printf.sprintf
             "%50s\t%30s\t%20.2f\t%20.2f\t%10s"
             name
             type_
             min
             max
             (match change with
             | `Noop -> "noop"
             | `Add -> "add"
             | `Remove -> "remove"))
         t.resources)
