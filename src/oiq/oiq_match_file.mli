type t [@@deriving to_yojson]

val make : (Oiq_tf.Resource.t * Oiq_prices.Product.t list) list -> t
