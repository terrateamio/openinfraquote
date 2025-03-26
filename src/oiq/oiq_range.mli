type 'a t = {
  min : 'a;
  max : 'a;
}
[@@deriving yojson, show, eq, ord]

val make : min:'a -> max:'a -> 'a t
val append : ('a -> 'a -> 'a) -> 'a t -> 'a t -> 'a t
