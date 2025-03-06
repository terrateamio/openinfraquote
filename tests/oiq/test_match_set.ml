let test_basic_keys () =
  let params = [ ("name", "Jms Dnns"); ("age", "21"); ("is_drummer", "yup") ] in
  assert (Oiq_match_set.to_keys params = [ "name=John%20Doe&age=30&city=New%20York" ])

let test_empty_keys () =
  let params = [] in
  assert (Oiq_match_set.to_keys params = [ "" ])

let test_single_key () =
  let params = [ ("fiona", "apple") ] in
  assert (Oiq_match_set.to_keys params = [ "fiona=apple" ])

let test_special_chars () =
  let params = [ ("has some spaces", "spaces & special=chars") ] in
  assert (Oiq_match_set.to_keys params = [ "has%20some%20spaces=spaces%20%26%20special%3Dchars" ])

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
  test_basic_keys ();
  test_empty_keys ();
  test_single_key ();
  test_special_chars ();
  test_subset ();
  test_of_string ();
  test_subset_of_string ()
