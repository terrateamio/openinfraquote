type 'a t = {
  min : 'a;
  max : 'a;
}
[@@deriving yojson, show, eq, ord]

val make : min:'a -> max:'a -> 'a t
val append : ('a -> 'a -> 'a) -> 'a t -> 'a t -> 'a t

(** Returns a new range that represents the overlap of [t1] and [t2] or [None] if there is no
    overlap. *)
val overlap : ('a -> 'a -> int) -> 'a t -> 'a t -> 'a t option
