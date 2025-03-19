module Match = struct
  type t = {
    resource : Oiq_tf.Resource.t;
    products : Oiq_prices.Product.t list;
  }
  [@@deriving yojson]

  let make resource products = { resource; products }
  let resource t = t.resource
  let products t = t.products
end

type t = {
  matches : Match.t list;
  date : string;
}
[@@deriving yojson]

let make matches = { matches; date = ISO8601.Permissive.string_of_datetime (Unix.gettimeofday ()) }
let matches t = t.matches
let date t = t.date
