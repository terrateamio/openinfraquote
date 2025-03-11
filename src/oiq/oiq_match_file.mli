type t

val make : Oiq_match_pair.t list -> t
val add : t -> Oiq_match_pair.t -> t
val to_yojson : t -> Yojson.Safe.t
