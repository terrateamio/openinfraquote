type t = { matches : Oiq_match_pair.t list } [@@deriving to_yojson]

let make pairs = { matches = pairs }
let add mf mp = { matches = mp :: mf.matches }
let to_yojson t = to_yojson t
