module Match : sig
  type t [@@deriving yojson]

  val make : Oiq_tf.Resource.t -> Oiq_prices.Product.t list -> Oiq_tf.Plan.change -> t
  val resource : t -> Oiq_tf.Resource.t
  val change : t -> Oiq_tf.Plan.change
  val products : t -> Oiq_prices.Product.t list
end

type t [@@deriving yojson]

val make : Match.t list -> t
val matches : t -> Match.t list
val date : t -> string
