(** Defines how to calculate the usage of a resource for pricing. [default] is a built-in set of
    usages. [from_channel] will read usage from an [in_channel] and prepend to [defaults].

    IMPORTANT: Order matters! Each usage entry is checked in the order it is presented and the first
    match is returned. The usage file should always be ordered in most-specific to least-specific.
*)

module Usage : sig
  type t [@@deriving yojson, show]

  val time : t -> int Oiq_range.t
  val operations : t -> int Oiq_range.t
  val data : t -> int Oiq_range.t
  val make : int Oiq_range.t -> t

  (** Multiply all usage values by a factor *)
  val multiply : int -> t -> t
end

(** Reference-based usage multiplier.
    Allows usage to be multiplied by a value from a referenced resource.

    For example, an ECS service's vCPU usage can be multiplied by the
    task definition's CPU value. *)
module Ref_multiplier : sig
  type t [@@deriving yojson, show]

  (** Look up the multiplier value from a resource using reference info.
      Returns the multiplier value (after applying divisor), or 1 if not found. *)
  val resolve : Oiq_tf.Refs.t -> string -> t -> int
end

(** Value-based usage multiplier.
    Allows usage to be multiplied by a value from the resource's own attributes.

    For example, an ECS service's usage can be multiplied by its desired_count. *)
module Value_multiplier : sig
  type t [@@deriving yojson, show]

  (** Look up the multiplier value from the resource's own match set.
      Returns the multiplier value (after applying divisor), or 1 if not found. *)
  val resolve : Oiq_match_set.t -> t -> int
end

module Entry : sig
  type accessor
  type 'a t [@@deriving yojson, show]

  val make :
    ?divisor:int ->
    ?ref_multiplier:Ref_multiplier.t ->
    ?value_multiplier:Value_multiplier.t ->
    description:string ->
    match_query:Oiq_match_query.t ->
    usage:'a ->
    unit ->
    'a t

  val usage : 'a t -> 'a
  val with_usage : 'a -> 'b t -> 'a t
  val match_query : 'a t -> Oiq_match_query.t
  val description : 'a t -> string
  val divisor : 'a t -> int option
  val ref_multiplier : 'a t -> Ref_multiplier.t option
  val value_multiplier : 'a t -> Value_multiplier.t option

  (** Given a usage amount (this is part of pricing information) and an entry, construct a new entry
      if the usage amount lies within the range expressed in the entry. The usage of the resulting
      entry will correspond to the amount of usage in the usage amount.

      For example, if given a usage amount of (0, 10) and usage range of (0, 10), the resulting
      usage would be (0, 10).

      If given a usage amount of (0, 10) and a usage range of (0, 5) the resulting usage would be
      (0, 5).

      If given a usage amount of (5, 10) and a usage range of (0, 10) the resulting usage would be
      (0, 5) (between 0 and 5 units could be priced at the (5, 10) usage level).

      If given a usage amount of (5, 10) and a usage range of (3, 7) the resulting usage would be
      (0, 2) (because 7 is 5 + 2, only 2 units could be priced given that usage amount).

      If given a usage amount of (5, 10) and a usage range of (6, 9) the resulting usage would be
      (1, 4)

      If given a usage amount of (5, 10) and a usage range of (2, 11) the resulting usage would be
      (0, 5).

      If given a usage amount of (5, 10) and a usage range of (6, 12) the resulting usage would be
      (1, 5).

      If give an a usage amount of (0, 10) and a usage range of (11, 11) the resulting usage would
      be (10, 10).

      If given a usage amount of (0, 10) and a usage range of (11, 20) the resulting usage would be
      (10, 10) (there will always be 10 units priced at this usage amount).

      If given a usage amount of (5, 10) and a usage range of (0, 4), None would be returned because
      there is no overlap. *)
  val bound_to_usage_amount : accessor -> int Oiq_range.t -> Usage.t t -> Usage.t t option

  val time : accessor
  val operations : accessor
  val data : accessor
end

type of_channel_err = [ `Usage_file_err of string ] [@@deriving show]
type t [@@deriving to_yojson]

val default : unit -> t
val of_channel : in_channel -> (t, [> of_channel_err ]) result
val match_ : Oiq_match_set.t -> t -> Usage.t option Entry.t option
