let test_subset () =
  let ms1 = Oiq_match_set.of_list [ ("foo", ""); ("bar", "") ] in
  let ms2 = Oiq_match_set.of_list [ ("foo", ""); ("fighters", ""); ("bar", "") ] in
  assert (Oiq_match_set.subset ~super:ms2 ms1)

let test_of_string () =
  assert (CCResult.is_ok @@ Oiq_match_set.of_string "resource_type=ec2&instance_type=m4.large")

let test_subset_for_matched_sets () =
  let ms1 = CCResult.get_exn @@ Oiq_match_set.of_string "foo=fighters&amon=tobin" in
  let ms2 = Oiq_match_set.of_list [ ("foo", "fighters"); ("amon", "tobin") ] in
  assert (Oiq_match_set.subset ~super:ms2 ms1)

let test_subset_passes_if_superset_is_bigger () =
  let ms1 = CCResult.get_exn @@ Oiq_match_set.of_string "foo=fighters" in
  let ms2 = Oiq_match_set.of_list [ ("foo", "fighters"); ("amon", "tobin") ] in
  assert (Oiq_match_set.subset ~super:ms2 ms1)

let test_subset_fails_if_superset_is_smaller () =
  let ms1 = CCResult.get_exn @@ Oiq_match_set.of_string "foo=fighters&amon=tobin" in
  let ms2 = Oiq_match_set.of_list [ ("foo", "fighters") ] in
  assert (not (Oiq_match_set.subset ~super:ms2 ms1))

let () =
  test_subset ();
  test_of_string ();
  test_subset_for_matched_sets ();
  test_subset_passes_if_superset_is_bigger ();
  test_subset_fails_if_superset_is_smaller ()
