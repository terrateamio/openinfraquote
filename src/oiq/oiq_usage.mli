(** Defines how to calculate the usage of a resource for pricing. [default] is a built-in set of
    usages. [from_channel] will read usage from an [in_channel] and prepend to [defaults].

    IMPORTANT: Order matters! Each usage entry is checked in the order it is presented and the first
    match is returned. The usage file should always be ordered in most-specific to least-specific.
*)

module Usage : sig
  type t [@@deriving yojson]

  val hours : t -> int Oiq_range.t
  val operations : t -> int Oiq_range.t
  val data : t -> int Oiq_range.t
end

module Entry : sig
  type t [@@deriving yojson]

  val usage : t -> Usage.t
  val match_set : t -> Oiq_match_set.t
  val description : t -> string option
  val divisor : t -> int option
end

type of_channel_err = [ `Usage_file_err of string ] [@@deriving show]
type t

val default : unit -> t
val of_channel : in_channel -> (t, [> of_channel_err ]) result
val match_ : Oiq_match_set.t -> t -> Entry.t option
