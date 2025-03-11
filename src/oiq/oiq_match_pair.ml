type t = {
  resource : Oiq_tf.Resource.t;
  product : Oiq_prices.Product.t;
}
[@@deriving to_yojson]

let make resource product = { resource; product }
let to_yojson t = to_yojson t
