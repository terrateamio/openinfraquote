module Price_range = struct
  type t = {
    min : float;
    max : float;
  }
  [@@deriving to_yojson]
end

module Resource = struct
  let change_to_yojson = function
    | `Noop -> `String "noop"
    | `Add -> `String "add"
    | `Remove -> `String "remove"

  type t = {
    change : Oiq_tf.Plan.change; [@to_yojson change_to_yojson]
    name : string;
    products_max : Oiq_prices.Product.t list;
    products_min : Oiq_prices.Product.t list;
    total : Price_range.t;
    type_ : string; [@key "type"]
    usage : Oiq_usage.Usage.t;
  }
  [@@deriving to_yojson]
end

type t = {
  match_date : string;
  price_date : string;
  match_query : string list;
  resources : Resource.t list;
  total : Price_range.t;
  total_diff : Price_range.t;
}
[@@deriving to_yojson]

let hours = CCFun.(Oiq_usage.Usage.hours %> CCFloat.of_int)
let operations = CCFun.(Oiq_usage.Usage.operations %> CCFloat.of_int)
let data = CCFun.(Oiq_usage.Usage.data %> CCFloat.of_int)

let price_products usage products =
  let priced_products =
    CCList.sort (fun (_, l) (_, r) -> CCFloat.compare l r)
    @@ CCList.map
         (fun product ->
           let price = Oiq_prices.Product.price product in
           let quote =
             match price with
             | Oiq_prices.Price.Per_hour price -> hours usage *. price
             | Oiq_prices.Price.Per_operation price -> operations usage *. price
             | Oiq_prices.Price.Per_data price -> data usage *. price
           in
           (product, quote))
         products
  in
  match (CCList.head_opt priced_products, CCList.head_opt @@ CCList.rev priced_products) with
  | Some min, Some max -> (min, max)
  | _, _ -> assert false

let group_products products =
  (* We assume that products are grouped by what kind of price type they
     have. *)
  let per_hour, per_operation, per_data =
    CCList.fold_left
      (fun (per_hour, per_operation, per_data) p ->
        match Oiq_prices.Product.price p with
        | Oiq_prices.Price.Per_hour _ -> (p :: per_hour, per_operation, per_data)
        | Oiq_prices.Price.Per_operation _ -> (per_hour, p :: per_operation, per_data)
        | Oiq_prices.Price.Per_data _ -> (per_hour, per_operation, p :: per_data))
      ([], [], [])
      products
  in
  CCList.filter CCFun.(CCList.is_empty %> not) [ per_hour; per_operation; per_data ]

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
    CCList.filter_map (fun match_ ->
        let resource = Oiq_match_file.Match.resource match_ in
        let products = Oiq_match_file.Match.products match_ in
        match Oiq_usage.match_ resource usage with
        | Some entry when not (CCList.is_empty products) ->
            let usage = Oiq_usage.Entry.usage entry in
            let product_groups = group_products products in
            let d =
              if Oiq_match_file.Match.change match_ = `Remove then CCFloat.neg else CCFun.id
            in
            let (products_min, min), (products_max, max) =
              product_groups
              |> CCList.map (price_products usage)
              |> CCList.fold_left
                   (fun ((products_min, total_min), (products_max, total_max))
                        ((product_min, min), (product_max, max))
                      ->
                     ( (product_min :: products_min, total_min +. min),
                       (product_max :: products_max, total_max +. max) ))
                   (([], 0.0), ([], 0.0))
            in
            Some
              {
                Resource.change = Oiq_match_file.Match.change match_;
                name = Oiq_tf.Resource.name resource;
                products_max;
                products_min;
                total = { Price_range.min = d min; max = d max };
                type_ = Oiq_tf.Resource.type_ resource;
                usage;
              }
        | Some _ -> None
        | None when CCList.is_empty (Oiq_match_file.Match.products match_) -> None
        | None ->
            Logs.err (fun m -> m "No usage entry found for a resource with matching products");
            Logs.err (fun m -> m "Match:");
            Logs.err (fun m ->
                m "%s" (Yojson.Safe.pretty_to_string (Oiq_match_file.Match.to_yojson match_)));
            None)
    @@ filter_products match_query
    @@ Oiq_match_file.matches match_file
  in
  let total =
    CCList.fold_left
      (fun { Price_range.min; max }
           { Resource.total = { Price_range.min = min'; max = max' }; _ }
         -> { Price_range.min = min +. min'; max = max +. max' })
      { Price_range.min = 0.0; max = 0.0 }
      priced_resources
  in
  let total_diff =
    CCList.fold_left
      (fun ({ Price_range.min; max } as acc)
           { Resource.total = { Price_range.min = min'; max = max' }; change; _ }
         ->
        match change with
        | `Noop -> acc
        | `Add | `Remove -> { Price_range.min = min +. min'; max = max +. max' })
      { Price_range.min = 0.0; max = 0.0 }
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
    price_date = ISO8601.Permissive.string_of_datetime (Unix.gettimeofday ());
    resources = priced_resources;
    total;
    total_diff;
  }

let pretty_to_string t =
  Printf.sprintf
    "Match date: %s\n\
     Price date: %s\n\
     Match query: %s\n\
     Total Min: %0.2f USD\n\
     Total Max: %0.2f USD\n\
     Total Diff Min: %0.2f USD\n\
     Total Diff max: %0.2f USD\n\
     Resources\n\
     %30s\t%20s\t%20s\t%20s\t%10s\n\
     %s"
    t.match_date
    t.price_date
    (CCString.concat " | " t.match_query)
    t.total.Price_range.min
    t.total.Price_range.max
    t.total_diff.Price_range.min
    t.total_diff.Price_range.max
    "Name"
    "Type"
    "Min Price (USD)"
    "Max Price (USD)"
    "Change"
    (CCString.concat "\n"
    @@ CCList.map
         (fun { Resource.name; type_; total = { Price_range.min; max }; change; _ } ->
           Printf.sprintf
             "%30s\t%20s\t%20.2f\t%20.2f\t%10s"
             name
             type_
             min
             max
             (match change with
             | `Noop -> "noop"
             | `Add -> "add"
             | `Remove -> "remove"))
         t.resources)
