type price_err = [ `Error ] [@@deriving show]
type t [@@deriving to_yojson]

val price :
  ?match_query:Oiq_match_query.t ->
  usage:Oiq_usage.t ->
  Oiq_match_file.t ->
  (t, [> price_err ]) result

val pretty_to_string : t -> string
val to_markdown_string : t -> string
