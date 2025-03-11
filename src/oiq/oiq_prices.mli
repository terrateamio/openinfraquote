module Product : sig
  type t

  val of_row : string list -> t
  val to_match_set : t -> Oiq_match_set.t
  val to_yojson : t -> Yojson.Safe.t
end
