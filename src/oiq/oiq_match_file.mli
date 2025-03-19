module Match : sig
  type t [@@deriving yojson]

  val make : Oiq_tf.Resource.t -> Oiq_prices.Product.t list -> t
  val resource : t -> Oiq_tf.Resource.t
  val products : t -> Oiq_prices.Product.t list
end

type t [@@deriving yojson]

val make : Match.t list -> t
val matches : t -> Match.t list
val date : t -> string
