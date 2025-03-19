module Price : sig
  type t =
    | Per_hour of float
    | Per_operation of float
    | Per_data of float
end

module Product : sig
  type of_row_err =
    [ `Invalid_price_json_err of string
    | `Invalid_row_err of string list
    | `Invalid_usd_err of Yojson.Safe.t
    | `Invalid_unit_err of Yojson.Safe.t
    | `Invalid_price_err of Yojson.Safe.t * string
    | `Invalid_match_set_err of string
    ]
  [@@deriving show]

  type t [@@deriving yojson]

  val of_row : string list -> (t, [> of_row_err ]) result
  val to_match_set : t -> Oiq_match_set.t
  val prices : t -> Price.t list
end
