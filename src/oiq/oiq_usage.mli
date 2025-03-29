(** Defines how to calculate the usage of a resource for pricing. [default] is a built-in set of
    usages. [from_channel] will read usage from an [in_channel] and prepend to [defaults].

    IMPORTANT: Order matters! Each usage entry is checked in the order it is presented and the first
    match is returned. The usage file should always be ordered in most-specific to least-specific.
*)

module Usage : sig
  type t [@@deriving yojson]

  val time : t -> int Oiq_range.t
  val operations : t -> int Oiq_range.t
  val data : t -> int Oiq_range.t
end

module Entry : sig
  type accessor
  type t [@@deriving yojson]

  val usage : t -> Usage.t
  val match_query : t -> Oiq_match_query.t
  val description : t -> string option
  val divisor : t -> int option

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
  val bound_to_usage_amount : accessor -> int Oiq_range.t -> t -> t option

  val time : accessor
  val operations : accessor
  val data : accessor
end

type of_channel_err = [ `Usage_file_err of string ] [@@deriving show]
type t

val default : unit -> t
val of_channel : in_channel -> (t, [> of_channel_err ]) result
val match_ : Oiq_match_set.t -> t -> Entry.t option
