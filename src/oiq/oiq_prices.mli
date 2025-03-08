module Product : sig
  type t

  val of_row : string list -> t
  val to_match_str : t -> string
  val to_match_set : t -> Oiq_match_set.t
  val to_price_json : t -> Yojson.Safe.t
end
