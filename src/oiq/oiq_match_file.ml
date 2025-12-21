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

(** Reference information extracted from terraform configuration block.
    Maps resource address -> attribute name -> list of referenced resource addresses.
    This is stored in the match file so the price stage can resolve references
    without re-parsing the terraform plan. *)
module Ref_info = struct
  (** A single reference entry: resource address, attribute, and referenced addresses *)
  type entry = {
    address : string;
    attribute : string;
    references : string list;
  }
  [@@deriving yojson]

  type t = entry list [@@deriving yojson]

  let empty : t = []

  (** Build ref_info from a Refs context. *)
  let of_refs (refs : Oiq_tf.Refs.t) (resources : Oiq_tf.Resource.t list) : t =
    CCList.filter_map
      (fun res ->
        let addr = Oiq_tf.Resource.address res in
        (* Get all attributes that have references for this resource *)
        let all_refs = Oiq_tf.Refs.get_all_references refs addr in
        let entries =
          CCList.filter_map
            (fun (attr, ref_addrs) ->
              if CCList.is_empty ref_addrs then None
              else Some { address = addr; attribute = attr; references = ref_addrs })
            all_refs
        in
        match entries with
        | [] -> None
        | entries -> Some entries)
      resources
    |> CCList.flatten

  (** Build a Refs context from ref_info and resources.
      This reconstructs a full Refs context by combining the resources
      with the serialized reference information. *)
  let to_refs (ref_info : t) (resources : Oiq_tf.Resource.t list) : Oiq_tf.Refs.t =
    (* First build the base refs from resources *)
    let base = Oiq_tf.Refs.of_resources resources in
    (* Then add the reference mappings from ref_info *)
    let entries =
      CCList.map
        (fun { address; attribute; references } -> (address, attribute, references))
        ref_info
    in
    Oiq_tf.Refs.add_references entries base
end

type t = {
  matches : Match.t list;
  date : string;
  ref_info : Ref_info.t; [@default []]
}
[@@deriving yojson]

let make ?(ref_info = Ref_info.empty) matches =
  { matches; ref_info; date = ISO8601.Permissive.string_of_datetime (Unix.gettimeofday ()) }

let matches t = t.matches
let date t = t.date
let ref_info t = t.ref_info
