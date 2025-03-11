type t

val make : Oiq_tf.Resource.t -> Oiq_prices.Product.t -> t
val to_yojson : t -> Yojson.Safe.t
