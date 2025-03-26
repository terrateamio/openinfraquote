type 'a t = {
  min : 'a;
  max : 'a;
}
[@@deriving yojson, show, eq, ord]

let make ~min ~max = { min; max }
let append f t1 t2 = { min = f t1.min t2.min; max = f t1.max t2.max }
