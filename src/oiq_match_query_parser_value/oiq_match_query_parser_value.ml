type t =
  | And of t * t
  | Equals of (string * string)
  | Key of string
  | Not of t
  | Or of t * t
[@@deriving show]
