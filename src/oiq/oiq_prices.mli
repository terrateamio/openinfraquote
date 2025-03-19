module Price : sig
  type t
end

module Product : sig
  type of_row_err =
    [ `Invalid_price_json_err of string
    | `Invalid_row_err of string list
    | `Invalid_usd_err of Yojson.Safe.t
    | `Invalid_unit_err of Yojson.Safe.t
    | `Invalid_price_err of Yojson.Safe.t * string
    ]
  [@@deriving show]

  type t

  val of_row : string list -> (t, [> of_row_err ]) result
  val to_match_set : t -> Oiq_match_set.t
  val to_yojson : t -> Yojson.Safe.t
end
