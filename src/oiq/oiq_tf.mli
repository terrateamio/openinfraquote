val type_ : Yojson.Safe.t -> [ `Plan | `State | `Unknown ]

module Resource : sig
  type t

  val to_match_set : t -> Oiq_match_set.t
  val to_yojson : t -> Yojson.Safe.t
end

module Plan : sig
  type err = [ `Invalid_plan of string ] [@@deriving show]
  type t

  val of_yojson : Yojson.Safe.t -> (t, [> err ]) result
  val resources : t -> Resource.t list
end

module State : sig
  type err = [ `Invalid_state of string ] [@@deriving show]
  type t

  val of_yojson : Yojson.Safe.t -> (t, [> err ]) result
  val resources : t -> Resource.t list
end
