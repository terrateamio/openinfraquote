type t = { oiq : Oiq_match_pair.t list } [@@deriving to_yojson]

let make pairs = { oiq = pairs }
let add mf mp = { oiq = mp :: mf.oiq }
let to_yojson t = to_yojson t
