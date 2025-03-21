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
    product_max : Oiq_prices.Product.t;
    product_min : Oiq_prices.Product.t;
    total : Price_range.t;
    type_ : string; [@key "type"]
  }
  [@@deriving to_yojson]
end

type t = {
  match_date : string;
  price_date : string;
  resources : Resource.t list;
  total : Price_range.t;
  total_diff : Price_range.t;
}
[@@deriving to_yojson]

let hours = CCFun.(Oiq_usage.Usage.hours %> CCOption.get_or ~default:0 %> CCFloat.of_int)
let operations = CCFun.(Oiq_usage.Usage.operations %> CCOption.get_or ~default:0 %> CCFloat.of_int)
let data = CCFun.(Oiq_usage.Usage.data %> CCOption.get_or ~default:0 %> CCFloat.of_int)

let price_products usage products =
  let priced_products =
    CCList.sort (fun (_, l) (_, r) -> CCFloat.compare l r)
    @@ CCList.map
         (fun product ->
           ( product,
             CCList.fold_left
               (fun acc price ->
                 match price with
                 | Oiq_prices.Price.Per_hour amount -> hours usage *. amount
                 | Oiq_prices.Price.Per_data amount -> data usage *. amount
                 | Oiq_prices.Price.Per_operation amount -> operations usage *. amount)
               0.0
               (Oiq_prices.Product.prices product) ))
         products
  in
  match (CCList.head_opt priced_products, CCList.head_opt @@ CCList.rev priced_products) with
  | Some min, Some max -> (min, max)
  | _, _ -> assert false

let price ~usage match_file =
  let priced_resources =
    CCList.filter_map (fun match_ ->
        let resource = Oiq_match_file.Match.resource match_ in
        match Oiq_usage.match_ resource usage with
        | Some entry ->
            let (product_min, min), (product_max, max) =
              price_products (Oiq_usage.Entry.usage entry) (Oiq_match_file.Match.products match_)
            in
            let d =
              if Oiq_match_file.Match.change match_ = `Remove then CCFloat.neg else CCFun.id
            in
            Some
              {
                Resource.name = Oiq_tf.Resource.name resource;
                type_ = Oiq_tf.Resource.type_ resource;
                product_min;
                product_max;
                total = { Price_range.min = d min; max = d max };
                change = Oiq_match_file.Match.change match_;
              }
        | None when CCList.is_empty (Oiq_match_file.Match.products match_) -> None
        | None ->
            Logs.err (fun m -> m "No usage entry found for a resource with matching products");
            Logs.err (fun m -> m "Resource:");
            Logs.err (fun m ->
                m "%s" (Yojson.Safe.pretty_to_string (Oiq_tf.Resource.to_yojson resource)));
            assert false)
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
  {
    match_date = Oiq_match_file.date match_file;
    price_date = ISO8601.Permissive.string_of_datetime (Unix.gettimeofday ());
    resources = priced_resources;
    total;
    total_diff;
  }

let pretty_to_string t =
  Printf.sprintf
    "Match date: %s\n\
     Price date: %s\n\
     Total Min: %0.2f USD\n\
     Total Max: %0.2f USD\n\
     Total Diff Min: %0.2f USD\n\
     Total Diff max: %0.2f USD\n\
     Resources\n\
     %30s\t%20s\t%20s\t%20s\t%10s\n\
     %s"
    t.match_date
    t.price_date
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
