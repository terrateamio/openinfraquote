let test_subset () =
  let ms1 = CCResult.get_exn @@ Oiq_match_set.of_list [ "foo"; "bar" ] in
  let ms2 = CCResult.get_exn @@ Oiq_match_set.of_list [ "foo"; "fighters"; "bar" ] in
  assert (Oiq_match_set.subset ~super:ms2 ms1)

let test_of_string () =
  assert (CCResult.is_ok @@ Oiq_match_set.of_string "resource_type=ec2&instance_type=m4.large")

let test_subset_of_string () =
  let ms1 = CCResult.get_exn @@ Oiq_match_set.of_string "foo&bar" in
  let ms2 = CCResult.get_exn @@ Oiq_match_set.of_list [ "foo"; "fighters"; "bar" ] in
  assert (Oiq_match_set.subset ~super:ms2 ms1)

let () =
  test_subset ();
  test_of_string ();
  test_subset_of_string ()
