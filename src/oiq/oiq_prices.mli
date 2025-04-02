module Price : sig
  type t =
    | Per_time of float
    | Per_operation of float
    | Per_data of float
    | Attr of string
end

module Product : sig
  type of_row_err =
    [ `Invalid_row_err of string list
    | `Invalid_price_err of string
    | `Invalid_match_set_err of string
    | `Invalid_pricing_match_set_err of string
    | `Invalid_price_type_err of string
    | `Empty_match_set_err
    ]
  [@@deriving show]

  type t [@@deriving yojson]

  val of_row : string list -> (t, [> of_row_err ]) result
  val to_match_set : t -> Oiq_match_set.t
  val pricing_match_set : t -> Oiq_match_set.t
  val price : t -> Price.t
end
