module Match : sig
  type t [@@deriving yojson]

  val make : Oiq_tf.Resource.t -> Oiq_prices.Product.t list -> Oiq_tf.Plan.change -> t
  val resource : t -> Oiq_tf.Resource.t
  val change : t -> Oiq_tf.Plan.change
  val products : t -> Oiq_prices.Product.t list
end

(** Reference information extracted from terraform configuration block.
    This is stored in the match file so the price stage can resolve references
    without re-parsing the terraform plan. *)
module Ref_info : sig
  (** A single reference entry: resource address, attribute, and referenced addresses *)
  type entry = {
    address : string;
    attribute : string;
    references : string list;
  }
  [@@deriving yojson]

  type t [@@deriving yojson]

  val empty : t

  (** Build ref_info from a Refs context and list of resources. *)
  val of_refs : Oiq_tf.Refs.t -> Oiq_tf.Resource.t list -> t

  (** Build a Refs context from ref_info and resources. *)
  val to_refs : t -> Oiq_tf.Resource.t list -> Oiq_tf.Refs.t
end

type t [@@deriving yojson]

val make : ?ref_info:Ref_info.t -> Match.t list -> t
val matches : t -> Match.t list
val date : t -> string
val ref_info : t -> Ref_info.t
