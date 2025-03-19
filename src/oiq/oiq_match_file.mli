type t [@@deriving to_yojson]

val make : Oiq_match_pair.t list -> t
val add : t -> Oiq_match_pair.t -> t
