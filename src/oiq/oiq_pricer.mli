type t [@@deriving to_yojson]

val price : usage:Oiq_usage.t -> Oiq_match_file.t -> t
val pretty_to_string : t -> string
