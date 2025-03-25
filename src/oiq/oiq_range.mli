type 'a t = {
  min : 'a;
  max : 'a;
}
[@@deriving yojson, show, eq]

val append : ('a -> 'a -> 'a) -> 'a t -> 'a t -> 'a t
