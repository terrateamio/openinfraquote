module Match = struct
  type t = {
    resource : Oiq_tf.Resource.t;
    products : Oiq_prices.Product.t list;
  }
  [@@deriving yojson]

  let make resource products = { resource; products }
end

type t = { matches : Match.t list } [@@deriving yojson]

let make matches = { matches }
