module Price_range = struct
  type t = float Oiq_range.t [@@deriving to_yojson]

  let empty = { Oiq_range.min = 0.0; max = 0.0 }
  let sum = Oiq_range.append ( +. )
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
  prev_price : Price_range.t;
  price : Price_range.t;
  price_date : string;
  price_diff : Price_range.t;
  resources : Resource.t list;
}
[@@deriving to_yojson]

(* If products have a provision amount, filter the products out based on if they are within the usage. *)
let apply_provision_amount entry products =
  CCList.filter
    (fun product ->
      let ms = Oiq_prices.Product.pricing_match_set product in
      match
        ( Oiq_match_set.find_by_key "start_provision_amount" ms,
          Oiq_match_set.find_by_key "end_provision_amount" ms )
      with
      | Some (_, start_provision_amount), Some (_, end_provision_amount) ->
          let start_provision_amount =
            CCOption.get_exn_or ("start_provision_amount: " ^ start_provision_amount)
            @@ CCInt.of_string start_provision_amount
          in
          let end_provision_amount =
            CCOption.get_exn_or ("end_provision_amount: " ^ end_provision_amount)
            @@ CCInt.of_string end_provision_amount
          in
          let provision_range =
            Oiq_range.make ~min:start_provision_amount ~max:end_provision_amount
          in
          let priced_by =
            match Oiq_prices.Product.price product with
            | Oiq_prices.Price.Per_hour _ -> Oiq_usage.Usage.hours @@ Oiq_usage.Entry.usage entry
            | Oiq_prices.Price.Per_operation _ ->
                Oiq_usage.Usage.operations @@ Oiq_usage.Entry.usage entry
            | Oiq_prices.Price.Per_data _ -> Oiq_usage.Usage.data @@ Oiq_usage.Entry.usage entry
          in
          CCOption.is_some @@ Oiq_range.overlap CCInt.compare provision_range priced_by
      | None, None -> true
      | Some _, None | None, Some _ -> assert false)
    products

(* Given a usage entry and a list of products, if the products have start/end
   usage amounts, make separate products of each distinct usage amount of bound
   the usage to that start/end usage.  This way we can price each individual
   usage range.


   WARNING: This can produce incoherent prices.  Currently, given a list of
   products, we have no way of knowing if a usage amount correspond to
   particular sections of the same product, so we just mix and match.

   For example, consider a product that has usage prices from (0, 10), (10, 20).
   And then it also has multiple regions.  Maybe region-1 has the lowest price
   for (0, 10) usage range but region-2 has the lowest for (10, 20).  We would
   price this resource at (0, 10) from region-1 and (10, 20) on region-2
   (assuming no region has been specified as a filter).  But obviously the
   resource is only in one region.  Probably the solution here is to include
   some identifier in the pricing match set that groups the usage amounts
   together. *)
let apply_usage_amount entry products =
  let module Usage_range_map = CCMap.Make (struct
    type t = int Oiq_range.t * [ `By_hour | `By_operation | `By_data ] [@@deriving ord]
  end) in
  (* We depend on the pricing sheet generator to ensure that:

     - If any product has [start_usage_amount] it also has [end_usage_amount].

     - If any product has [start_usage_amount] all products that match this
       usage have [end_usage_amount].  *)
  let has_usage_amount =
    CCList.exists
      (fun product ->
        let ms = Oiq_prices.Product.pricing_match_set product in
        match
          ( Oiq_match_set.find_by_key "start_usage_amount" ms,
            Oiq_match_set.find_by_key "end_usage_amount" ms )
        with
        | Some _, Some _ -> true
        | None, None -> false
        | Some _, None | None, Some _ -> assert false)
      products
  in
  let int_of_usage = function
    | "Inf" -> CCInt.max_int
    | v -> CCOption.get_exn_or ("int_of_usage: " ^ v) @@ CCInt.of_string v
  in
  if has_usage_amount then
    let products_grouped_by_usage_amount =
      CCList.fold_left
        (fun acc product ->
          let ms = Oiq_prices.Product.pricing_match_set product in
          let start_usage_amount =
            int_of_usage
            @@ snd
            @@ CCOption.get_exn_or "start_usage_amount"
            @@ Oiq_match_set.find_by_key "start_usage_amount" ms
          in
          let end_usage_amount =
            int_of_usage
            @@ snd
            @@ CCOption.get_exn_or "end_usage_amount"
            @@ Oiq_match_set.find_by_key "end_usage_amount" ms
          in
          let range = Oiq_range.make ~min:start_usage_amount ~max:end_usage_amount in
          let priced_by =
            match Oiq_prices.Product.price product with
            | Oiq_prices.Price.Per_hour _ -> `By_hour
            | Oiq_prices.Price.Per_operation _ -> `By_operation
            | Oiq_prices.Price.Per_data _ -> `By_data
          in
          Usage_range_map.add_to_list (range, priced_by) product acc)
        Usage_range_map.empty
        products
    in
    (* Given the grouped products, create new entry and products list by
       bounding the entry to the group's range.  A usage range may be too little
       for a group's range, so filter those out. *)
    CCList.filter_map (fun ((usage_range, priced_by), products) ->
        match priced_by with
        | `By_hour ->
            CCOption.map (fun entry -> (entry, products))
            @@ Oiq_usage.Entry.bound_to_usage_amount Oiq_usage.Entry.hours usage_range entry
        | `By_operation ->
            CCOption.map (fun entry -> (entry, products))
            @@ Oiq_usage.Entry.bound_to_usage_amount Oiq_usage.Entry.operations usage_range entry
        | `By_data ->
            CCOption.map (fun entry -> (entry, products))
            @@ Oiq_usage.Entry.bound_to_usage_amount Oiq_usage.Entry.data usage_range entry)
    @@ Usage_range_map.to_list products_grouped_by_usage_amount
  else [ (entry, products) ]

let hours f = CCFun.(Oiq_usage.Usage.hours %> f %> CCFloat.of_int)
let operations f = CCFun.(Oiq_usage.Usage.operations %> f %> CCFloat.of_int)
let data f = CCFun.(Oiq_usage.Usage.data %> f %> CCFloat.of_int)

let price_products entry products =
  let usage = Oiq_usage.Entry.usage entry in
  let divisor = CCFloat.of_int @@ CCOption.get_or ~default:1 @@ Oiq_usage.Entry.divisor entry in
  let priced_products =
    CCList.sort (fun (_, l) (_, r) -> CCFloat.compare l r)
    @@ CCList.flat_map
         (fun product ->
           let price = Oiq_prices.Product.price product in
           let quote f =
             match price with
             | Oiq_prices.Price.Per_hour price -> hours f usage /. divisor *. price
             | Oiq_prices.Price.Per_operation price -> operations f usage /. divisor *. price
             | Oiq_prices.Price.Per_data price -> data f usage /. divisor *. price
           in
           let min { Oiq_range.min; _ } = min in
           let max { Oiq_range.max; _ } = max in
           let min_quote = quote min in
           let max_quote = quote max in
           [ (product, min_quote); (product, max_quote) ])
         products
  in
  match (CCList.head_opt priced_products, CCList.head_opt @@ CCList.rev priced_products) with
  | Some min, Some max -> Oiq_range.make ~min ~max
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
        let priced_products =
          Entry_map.fold
            (fun entry products acc ->
              let priced =
                CCList.map (fun (entry, products) ->
                    let { Oiq_range.min = product_min, min; max = product_max, max } =
                      price_products entry products
                    in
                    {
                      Product.price = { Oiq_range.min; max };
                      product_max;
                      product_min;
                      usage = entry;
                    })
                @@ CCList.filter CCFun.(snd %> CCList.is_empty %> not)
                @@ apply_usage_amount entry
                @@ apply_provision_amount entry products
              in
              priced @ acc)
            usage_entries
            []
        in
        if not (CCList.is_empty priced_products) then
          let d = if Oiq_match_file.Match.change match_ = `Remove then CCFloat.neg else CCFun.id in
          let price =
            CCList.fold_left
              (fun acc { Product.price; _ } -> Price_range.sum acc price)
              Price_range.empty
              priced_products
          in
          Some
            {
              Resource.address = Oiq_tf.Resource.address resource;
              change = Oiq_match_file.Match.change match_;
              name = Oiq_tf.Resource.name resource;
              price = { Oiq_range.min = d price.Oiq_range.min; max = d price.Oiq_range.max };
              type_ = Oiq_tf.Resource.type_ resource;
              products = priced_products;
            }
        else None)
    @@ filter_products match_query
    @@ Oiq_match_file.matches match_file
  in
  let price =
    CCList.fold_left
      (fun acc { Resource.price; _ } -> Price_range.sum acc price)
      Price_range.empty
      priced_resources
  in
  let price_diff =
    CCList.fold_left
      (fun acc { Resource.price; change; _ } ->
        match change with
        | `Noop -> acc
        | `Add | `Remove -> Price_range.sum acc price)
      Price_range.empty
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
    prev_price = Oiq_range.append ( -. ) price price_diff;
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
     Min Previous Price: %0.2f USD\n\
     Max Previous Price: %0.2f USD\n\
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
    t.prev_price.Oiq_range.min
    t.prev_price.Oiq_range.max
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
