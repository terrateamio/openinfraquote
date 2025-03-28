let test_overlap_1 () =
  let r1 = Oiq_range.make ~min:0 ~max:5 in
  let r2 = Oiq_range.make ~min:6 ~max:10 in
  assert (Oiq_range.overlap CCInt.compare r1 r2 = None)

let test_overlap_2 () =
  let r1 = Oiq_range.make ~min:0 ~max:5 in
  let r2 = Oiq_range.make ~min:5 ~max:10 in
  assert (
    CCOption.equal
      (Oiq_range.equal CCInt.equal)
      (Oiq_range.overlap CCInt.compare r1 r2)
      (Some (Oiq_range.make ~min:5 ~max:5)))

let test_overlap_3 () =
  let r1 = Oiq_range.make ~min:0 ~max:5 in
  let r2 = Oiq_range.make ~min:3 ~max:10 in
  assert (
    CCOption.equal
      (Oiq_range.equal CCInt.equal)
      (Oiq_range.overlap CCInt.compare r1 r2)
      (Some (Oiq_range.make ~min:3 ~max:5)))

let test_overlap_4 () =
  let r1 = Oiq_range.make ~min:0 ~max:5 in
  let r2 = Oiq_range.make ~min:1 ~max:4 in
  assert (
    CCOption.equal
      (Oiq_range.equal CCInt.equal)
      (Oiq_range.overlap CCInt.compare r1 r2)
      (Some (Oiq_range.make ~min:1 ~max:4)))

let test_overlap_5 () =
  let r1 = Oiq_range.make ~min:0 ~max:5 in
  let r2 = Oiq_range.make ~min:(-10) ~max:10 in
  assert (
    CCOption.equal
      (Oiq_range.equal CCInt.equal)
      (Oiq_range.overlap CCInt.compare r1 r2)
      (Some (Oiq_range.make ~min:0 ~max:5)))

(* And the reverse *)
let test_overlap_10 () =
  let r2 = Oiq_range.make ~min:0 ~max:5 in
  let r1 = Oiq_range.make ~min:6 ~max:10 in
  assert (Oiq_range.overlap CCInt.compare r1 r2 = None)

let test_overlap_20 () =
  let r2 = Oiq_range.make ~min:0 ~max:5 in
  let r1 = Oiq_range.make ~min:5 ~max:10 in
  assert (
    CCOption.equal
      (Oiq_range.equal CCInt.equal)
      (Oiq_range.overlap CCInt.compare r1 r2)
      (Some (Oiq_range.make ~min:5 ~max:5)))

let test_overlap_30 () =
  let r2 = Oiq_range.make ~min:0 ~max:5 in
  let r1 = Oiq_range.make ~min:3 ~max:10 in
  assert (
    CCOption.equal
      (Oiq_range.equal CCInt.equal)
      (Oiq_range.overlap CCInt.compare r1 r2)
      (Some (Oiq_range.make ~min:3 ~max:5)))

let test_overlap_40 () =
  let r2 = Oiq_range.make ~min:0 ~max:5 in
  let r1 = Oiq_range.make ~min:1 ~max:4 in
  assert (
    CCOption.equal
      (Oiq_range.equal CCInt.equal)
      (Oiq_range.overlap CCInt.compare r1 r2)
      (Some (Oiq_range.make ~min:1 ~max:4)))

let test_overlap_50 () =
  let r2 = Oiq_range.make ~min:0 ~max:5 in
  let r1 = Oiq_range.make ~min:(-10) ~max:10 in
  assert (
    CCOption.equal
      (Oiq_range.equal CCInt.equal)
      (Oiq_range.overlap CCInt.compare r1 r2)
      (Some (Oiq_range.make ~min:0 ~max:5)))

let () =
  test_overlap_1 ();
  test_overlap_2 ();
  test_overlap_3 ();
  test_overlap_4 ();
  test_overlap_5 ();
  test_overlap_10 ();
  test_overlap_20 ();
  test_overlap_30 ();
  test_overlap_40 ();
  test_overlap_50 ()
