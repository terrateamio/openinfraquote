type t = { matches : (Oiq_tf.Resource.t * Oiq_prices.Product.t list) list } [@@deriving to_yojson]

let make matches = { matches }
