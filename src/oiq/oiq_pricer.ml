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
    usage : Oiq_usage.Usage.t Oiq_usage.Entry.t;
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

type price_err =
  [ `Resource_missing_attr_err of
    Oiq_match_set.t * Oiq_usage.Usage.t option Oiq_usage.Entry.t * Oiq_prices.Product.t
  ]
[@@deriving show]

exception Price_err of price_err

type t = {
  match_date : string;
  match_query : string;
  prev_price : Price_range.t;
  price : Price_range.t;
  price_date : string;
  price_diff : Price_range.t;
  resources : Resource.t list;
}
[@@deriving to_yojson]

let int_of_usage = function
  | "Inf" -> CCInt.max_int
  | v -> CCOption.get_exn_or ("int_of_usage: " ^ v) @@ CCInt.of_string v

(* If products have a provision amount, filter the products out based on if they
   are within the usage. *)
let apply_provision_amount entry products =
  ( entry,
    CCList.filter
      (fun product ->
        let ms = Oiq_prices.Product.pricing_match_set product in
        match
          ( Oiq_match_set.find_by_key "start_provision_amount" ms,
            Oiq_match_set.find_by_key "end_provision_amount" ms )
        with
        | Some (_, start_provision_amount), Some (_, end_provision_amount) ->
            let start_provision_amount = int_of_usage start_provision_amount in
            let end_provision_amount = int_of_usage end_provision_amount in
            let provision_range =
              Oiq_range.make ~min:start_provision_amount ~max:end_provision_amount
            in
            let usage = Oiq_usage.Entry.usage entry in
            let priced_by =
              match Oiq_prices.Product.price product with
              | Oiq_prices.Price.Per_time _ -> Oiq_usage.Usage.time usage
              | Oiq_prices.Price.Per_operation _ -> Oiq_usage.Usage.operations usage
              | Oiq_prices.Price.Per_data _ -> Oiq_usage.Usage.data usage
              | Oiq_prices.Price.Attr (_, _) -> Oiq_usage.Usage.data usage
            in
            CCOption.is_some @@ Oiq_range.overlap CCInt.compare provision_range priced_by
        | None, None -> true
        | Some _, None | None, Some _ -> assert false)
      products )

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
    type t = int Oiq_range.t * [ `By_time | `By_operation | `By_data ] [@@deriving ord]
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
            | Oiq_prices.Price.Per_time _ -> `By_time
            | Oiq_prices.Price.Per_operation _ -> `By_operation
            | Oiq_prices.Price.Per_data _ -> `By_data
            | Oiq_prices.Price.Attr _ -> `By_data
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
        | `By_time ->
            CCOption.map (fun entry -> (entry, products))
            @@ Oiq_usage.Entry.bound_to_usage_amount Oiq_usage.Entry.time usage_range entry
        | `By_operation ->
            CCOption.map (fun entry -> (entry, products))
            @@ Oiq_usage.Entry.bound_to_usage_amount Oiq_usage.Entry.operations usage_range entry
        | `By_data ->
            CCOption.map (fun entry -> (entry, products))
            @@ Oiq_usage.Entry.bound_to_usage_amount Oiq_usage.Entry.data usage_range entry)
    @@ Usage_range_map.to_list products_grouped_by_usage_amount
  else [ (entry, products) ]

let time f = CCFun.(Oiq_usage.Usage.time %> f %> CCFloat.of_int)
let operations f = CCFun.(Oiq_usage.Usage.operations %> f %> CCFloat.of_int)
let data f = CCFun.(Oiq_usage.Usage.data %> f %> CCFloat.of_int)

let price_products resource_ms entry products =
  let usage = Oiq_usage.Entry.usage entry in
  let divisor = CCFloat.of_int @@ CCOption.get_or ~default:1 @@ Oiq_usage.Entry.divisor entry in
  let priced_products =
    CCList.sort (fun (_, l) (_, r) -> CCFloat.compare l r)
    @@ CCList.flat_map
         (fun product ->
           let price = Oiq_prices.Product.price product in
           let quote f =
             match price with
             | Oiq_prices.Price.Per_time price -> time f usage /. divisor *. price
             | Oiq_prices.Price.Per_operation price -> operations f usage /. divisor *. price
             | Oiq_prices.Price.Per_data price -> data f usage /. divisor *. price
             | Oiq_prices.Price.Attr (_, price) -> data f usage /. divisor *. price
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
  match match_query with
  | None -> matches
  | Some match_query ->
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
                Oiq_match_query.eval ms match_query)
              (Oiq_match_file.Match.products match_)
          in
          Oiq_match_file.Match.make
            (Oiq_match_file.Match.resource match_)
            products
            (Oiq_match_file.Match.change match_))
        matches

let synthesize_usage_from_attr resource_ms entry products =
  let all_attr_based =
    CCList.for_all
      (fun product ->
        match Oiq_prices.Product.price product with
        | Oiq_prices.Price.Attr _ -> true
        | _ -> false)
      products
  in
  if all_attr_based then (
    (* Assert that they are all priced by the same attributes *)
    assert (
      1
      >= CCList.length
           (CCList.uniq
              ~eq:CCString.equal
              (CCList.map
                 (fun product ->
                   match Oiq_prices.Product.price product with
                   | Oiq_prices.Price.Attr (attr, _) -> attr
                   | _ -> assert false)
                 products)));
    (* There must be no usage for this entry in this case *)
    assert (CCOption.is_none @@ Oiq_usage.Entry.usage entry);
    match products with
    | [] -> (
        match Oiq_usage.Entry.usage entry with
        | Some usage -> (Oiq_usage.Entry.with_usage usage entry, products)
        | None -> assert false)
    | product :: _ -> (
        match Oiq_prices.Product.price product with
        | Oiq_prices.Price.Attr (attr, _) -> (
            match Oiq_match_set.find_by_key attr resource_ms with
            | Some (_, usage) ->
                let usage = CCInt.of_string_exn usage in
                let range = Oiq_range.make ~min:usage ~max:usage in
                let usage = Oiq_usage.Usage.make range in
                let entry = Oiq_usage.Entry.with_usage usage entry in
                (entry, products)
            | None -> raise (Price_err (`Resource_missing_attr_err (resource_ms, entry, product))))
        | _ -> raise (Failure "nyi")))
  else
    match Oiq_usage.Entry.usage entry with
    | Some usage -> (Oiq_usage.Entry.with_usage usage entry, products)
    | None -> assert false

let price' ?match_query ~usage match_file =
  let priced_resources =
    let module Entry_map = CCMap.Make (struct
      type t = Oiq_usage.Usage.t option Oiq_usage.Entry.t

      let compare e1 e2 =
        CCString.compare
          (Oiq_match_query.to_string (Oiq_usage.Entry.match_query e1))
          (Oiq_match_query.to_string (Oiq_usage.Entry.match_query e2))
    end) in
    CCList.filter_map (fun match_ ->
        let resource = Oiq_match_file.Match.resource match_ in
        let resource_ms = Oiq_tf.Resource.to_match_set resource in
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
                      price_products resource_ms entry products
                    in
                    {
                      Product.price = { Oiq_range.min; max };
                      product_max;
                      product_min;
                      usage = entry;
                    })
                @@ CCList.filter CCFun.(snd %> CCList.is_empty %> not)
                @@ CCFun.uncurry apply_usage_amount
                @@ CCFun.uncurry apply_provision_amount
                @@ synthesize_usage_from_attr resource_ms entry products
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
  let match_query = CCOption.map_or ~default:"" Oiq_match_query.to_string match_query in
  {
    match_date = Oiq_match_file.date match_file;
    match_query;
    prev_price = Oiq_range.append ( -. ) price price_diff;
    price;
    price_date = ISO8601.Permissive.string_of_datetime (Unix.gettimeofday ());
    price_diff;
    resources = priced_resources;
  }

let price ?match_query ~usage match_file =
  try Ok (price' ?match_query ~usage match_file) with Price_err (#price_err as err) -> Error err

let pretty_to_string t =
  let fmt_name address type_ name =
    if not (CCString.equal address (type_ ^ "." ^ name)) then
      CCString.concat "." @@ CCList.tl @@ CCString.split_on_char '.' address
    else name
  in
  let max_name =
    CCList.fold_left CCInt.max 0
    @@ CCList.map
         (fun { Resource.address; name; type_; _ } ->
           CCString.length @@ fmt_name address type_ name)
         t.resources
  in
  let max_type_ =
    CCList.fold_left CCInt.max 0
    @@ CCList.map (fun { Resource.type_; _ } -> CCString.length type_) t.resources
  in
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
     %*s\t%*s\t%20s\t%20s\t%10s\n\
     %s"
    t.match_date
    t.price_date
    t.match_query
    t.prev_price.Oiq_range.min
    t.prev_price.Oiq_range.max
    t.price.Oiq_range.min
    t.price.Oiq_range.max
    t.price_diff.Oiq_range.min
    t.price_diff.Oiq_range.max
    max_name
    "Name"
    max_type_
    "Type"
    "Min Price (USD)"
    "Max Price (USD)"
    "Change"
    (CCString.concat "\n"
    @@ CCList.map
         (fun { Resource.address; name; type_; price = { Oiq_range.min; max }; change; _ } ->
           let name = fmt_name address type_ name in
           Printf.sprintf
             "%*s\t%*s\t%20.2f\t%20.2f\t%10s"
             max_name
             name
             max_type_
             type_
             min
             max
             (match change with
             | `Noop -> "noop"
             | `Add -> "add"
             | `Remove -> "remove"))
         t.resources)

let to_markdown_string t =
  let fmt v = Printf.sprintf "%s$%.2f" (if v >= 0.0 then "" else "-") (CCFloat.abs v) in
  (* Initial header *)
  let lines = [ "### 💸 OpenInfraQuote Cost Estimate\n" ] in
  (* Price difference section *)
  let delta_min = t.price_diff.Oiq_range.min in
  let delta_max = t.price_diff.Oiq_range.max in
  let lines =
    if delta_min = 0.0 && delta_max = 0.0 then lines
    else
      lines
      @ [
          Printf.sprintf
            "Monthly cost is projected to **%s** by **%s - %s**\n"
            (if delta_max < 0.0 then "decrease" else "increase")
            (fmt (CCFloat.abs delta_min))
            (fmt (CCFloat.abs delta_max));
        ]
  in
  (* Summary table *)
  let lines =
    lines
    @ [
        "\n| Monthly Estimate | Amount             |";
        "|------------------|--------------------|";
        Printf.sprintf
          "| After changes    | %s - %s |"
          (fmt t.price.Oiq_range.min)
          (fmt t.price.Oiq_range.max);
        Printf.sprintf
          "| Before changes   | %s - %s |\n"
          (fmt t.prev_price.Oiq_range.min)
          (fmt t.prev_price.Oiq_range.max);
      ]
  in
  (* Group resources by change type *)
  let adds, removes, existing =
    CCList.fold_left
      (fun (a, r, e) resource ->
        match resource.Resource.change with
        | `Add -> (resource :: a, r, e)
        | `Remove -> (a, resource :: r, e)
        | `Noop -> (a, r, resource :: e))
      ([], [], [])
      t.resources
  in
  (* Helper to render a section of resources *)
  let render_section title resources =
    if CCList.is_empty resources then ""
    else
      let header = Printf.sprintf "<details>\n<summary>%s</summary>\n\n" title in
      let table =
        "| Resource | Type | Before changes | After changes |\n\
         |----------|------|----------------|----------------|\n"
      in
      let rows =
        CCString.concat
          "\n"
          (CCList.map
             (fun r ->
               let name =
                 if not (CCString.equal r.Resource.address (r.Resource.type_ ^ "." ^ r.Resource.name)) then
                   CCString.concat "." @@ CCList.tl @@ CCString.split_on_char '.' r.Resource.address
                 else r.Resource.name
               in
               let typ = r.Resource.type_ in
               let est_min = r.Resource.price.Oiq_range.min in
               let est_max = r.Resource.price.Oiq_range.max in
               Printf.sprintf
                 "| %s | %s | %s - %s | %s - %s |"
                 name
                 typ
                 (fmt t.prev_price.Oiq_range.min)
                 (fmt t.prev_price.Oiq_range.max)
                 (fmt est_min)
                 (fmt est_max))
             resources)
      in
      header ^ table ^ rows ^ "\n</details>\n"
  in
  CCString.concat
    "\n"
    (lines
    @ [
        render_section "🟢 Added resources" adds;
        render_section "🔴 Removed resources" removes;
        render_section "⚪ Existing resources" existing;
      ])
