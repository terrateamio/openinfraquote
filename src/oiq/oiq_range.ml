type 'a t = {
  min : 'a;
  max : 'a;
}
[@@deriving yojson, show, eq, ord]

let make ~min ~max = { min; max }
let append f t1 t2 = { min = f t1.min t2.min; max = f t1.max t2.max }

(* Given (0, 5) (6, 10) -> None

   Given (0, 5) (5, 10) -> Some (5, 5)

   Given (0, 5) (3, 10) -> Some (3, 5)

   Given (0, 5) (1, 4) -> Some (1, 4)

   Given (0, 5) (-10, 10) -> Some (0, 5)
 *)
let overlap cmp t1 t2 =
  let min' l r = if cmp l r < 0 then l else r in
  let max' l r = if cmp l r > 0 then l else r in
  (* If max of t1 is less than min of t2 or max of t2 is less than min of t1,
     then no overlap*)
  match (cmp t1.max t2.min, cmp t2.max t1.min) with
  | c1, c2 when c1 < 0 || c2 < 0 -> None
  | _, _ -> Some { min = max' t1.min t2.min; max = min' t1.max t2.max }
