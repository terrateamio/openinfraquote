val type_ : Yojson.Safe.t -> [ `Plan | `State | `Unknown ]

module Resource : sig
  type t [@@deriving yojson]

  val name : t -> string
  val type_ : t -> string
  val to_match_set : t -> Oiq_match_set.t
end

module Plan : sig
  type change =
    [ `Noop
    | `Add
    | `Remove
    ]

  type err = [ `Invalid_plan of string ] [@@deriving show]
  type t

  val of_yojson : Yojson.Safe.t -> (t, [> err ]) result
  val resources : t -> (Resource.t * change) list
end

module State : sig
  type err = [ `Invalid_state of string ] [@@deriving show]
  type t

  val of_yojson : Yojson.Safe.t -> (t, [> err ]) result
  val resources : t -> Resource.t list
end
