module Match : sig
  type t [@@deriving yojson]

  val make : Oiq_tf.Resource.t -> Oiq_prices.Product.t list -> t
end

type t [@@deriving yojson]

val make : Match.t list -> t
