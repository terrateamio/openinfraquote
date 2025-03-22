module Match = struct
  let change_to_yojson = function
    | `Noop -> `String "noop"
    | `Add -> `String "add"
    | `Remove -> `String "remove"

  let change_of_yojson json =
    let open CCResult.Infix in
    [%of_yojson: string] json
    >>= function
    | "noop" -> Ok `Noop
    | "add" -> Ok `Add
    | "remove" -> Ok `Remove
    | any -> Error (Printf.sprintf "Unknown change: %s" any)

  type t = {
    resource : Oiq_tf.Resource.t;
    products : Oiq_prices.Product.t list;
    change : Oiq_tf.Plan.change; [@to_yojson change_to_yojson] [@of_yojson change_of_yojson]
  }
  [@@deriving yojson]

  let make resource products change = { resource; products; change }
  let resource t = t.resource
  let change t = t.change
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
