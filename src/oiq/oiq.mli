type match_err =
  [ `Product_parse_err of Oiq_prices.Product.of_row_err
  | `Invalid_resource_file_err of string
  | Oiq_tf.Plan.err
  | Oiq_tf.State.err
  ]
[@@deriving show]

val match_ :
  pricing_root:string ->
  resource_files:string list ->
  output:out_channel ->
  (unit, match_err) result
