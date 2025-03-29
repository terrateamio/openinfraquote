type match_err =
  [ `Product_parse_err of Oiq_prices.Product.of_row_err
  | `Invalid_resource_file_err of string
  | Oiq_tf.Plan.err
  | Oiq_tf.State.err
  ]
[@@deriving show]

type price_err =
  [ `Invalid_match_file_err of string
  | Oiq_usage.of_channel_err
  ]
[@@deriving show]

val match_ :
  pricesheet:string -> resource_files:string list -> output:out_channel -> (unit, match_err) result

val price :
  ?usage:in_channel ->
  ?match_query:Oiq_match_query.t ->
  input:in_channel ->
  unit ->
  (Oiq_pricer.t, [> price_err ]) result
