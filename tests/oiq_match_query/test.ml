let get_err = function
  | Ok _ -> assert false
  | Error err -> err

let test_empty_query () =
  print_endline "test_empty_query";
  let ms = Oiq_match_set.of_list [ ("foo", "bar") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "" in
  assert (Oiq_match_query.eval ms q)

let test_empty_set_and_empty_query () =
  print_endline "test_empty_set_and_empty_query";
  let ms = Oiq_match_set.of_list [] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "" in
  assert (Oiq_match_query.eval ms q)

let test_key_match () =
  print_endline "test_key_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "foo" in
  assert (Oiq_match_query.eval ms q)

let test_key_fail () =
  print_endline "test_key_fail";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "bar" in
  assert (not (Oiq_match_query.eval ms q))

let test_key_value_match () =
  print_endline "test_key_value_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "foo = bar" in
  assert (Oiq_match_query.eval ms q)

let test_compact_key_value_match () =
  print_endline "test_compact_key_value_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "foo=bar" in
  assert (Oiq_match_query.eval ms q)

let test_key_value_and_match () =
  print_endline "test_key_value_and_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "foo = bar and baz = boom" in
  assert (Oiq_match_query.eval ms q)

let test_key_value_and_fail () =
  print_endline "test_key_value_and_fail";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "foo = bar and baz = bam" in
  assert (not (Oiq_match_query.eval ms q))

let test_key_value_or_both_match () =
  print_endline "test_key_value_or_both_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "foo = bar or baz = boom" in
  assert (Oiq_match_query.eval ms q)

let test_key_value_or_one_match () =
  print_endline "test_key_value_or_one_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "foo = bar or bar = boom" in
  assert (Oiq_match_query.eval ms q)

let test_not_key_match () =
  print_endline "test_not_key_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "not bar" in
  assert (Oiq_match_query.eval ms q)

let test_not_key_fail () =
  print_endline "test_not_key_fail";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "not foo" in
  assert (not (Oiq_match_query.eval ms q))

let test_not_key_value_match () =
  print_endline "test_not_key_value_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "not foo = baz" in
  assert (Oiq_match_query.eval ms q)

let test_not_key_value_fail () =
  print_endline "test_not_key_value_fail";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "not foo = bar" in
  assert (not (Oiq_match_query.eval ms q))

let test_single_quote_key_match () =
  print_endline "test_single_quote_key_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "'foo'" in
  assert (Oiq_match_query.eval ms q)

let test_double_quote_key_match () =
  print_endline "test_single_quote_key_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "\"foo\"" in
  assert (Oiq_match_query.eval ms q)

let test_and_precedence_match () =
  print_endline "test_and_precedence_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "foo = bam and baz = boom or baz = bam" in
  assert (not (Oiq_match_query.eval ms q))

let test_not_precedence_match () =
  print_endline "test_not_precedence_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "not foo = bar or baz = boom" in
  assert (Oiq_match_query.eval ms q)

let test_and_precedence_parens_equal () =
  print_endline "test_and_precedence_parens_equal";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q1 = CCResult.get_exn @@ Oiq_match_query.of_string "foo = bam and baz = boom or baz = bam" in
  let q2 =
    CCResult.get_exn @@ Oiq_match_query.of_string "(foo = bam and baz = boom) or baz = bam"
  in
  assert (Oiq_match_query.eval ms q1 = Oiq_match_query.eval ms q2)

let test_not_precedence_parens_equal () =
  print_endline "test_not_precedence_parens_equal";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q1 = CCResult.get_exn @@ Oiq_match_query.of_string "not foo = bar or baz = boom" in
  let q2 = CCResult.get_exn @@ Oiq_match_query.of_string "(not foo = bar) or baz = boom" in
  assert (Oiq_match_query.eval ms q1 = Oiq_match_query.eval ms q2)

let test_not_precedence_parens_equal_1 () =
  print_endline "test_not_precedence_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q1 = CCResult.get_exn @@ Oiq_match_query.of_string "not foo = bar" in
  let q2 = CCResult.get_exn @@ Oiq_match_query.of_string "not (foo = bar)" in
  assert (Oiq_match_query.eval ms q1 = Oiq_match_query.eval ms q2)

let test_simple_paren_expr_match () =
  print_endline "test_simple_paren_expr_match";
  let ms = Oiq_match_set.of_list [ ("foo", "bar"); ("baz", "boom") ] in
  let q = CCResult.get_exn @@ Oiq_match_query.of_string "(foo)" in
  assert (Oiq_match_query.eval ms q)

let test_unmatching_paren_error () =
  print_endline "test_unmatching_paren_error";
  let err = get_err @@ Oiq_match_query.of_string "(" in
  assert (err = `Error (Some { Oiq_match_query.lnum = 1; offset = 0 }, "(", "MISSING_RPAREN"))

let test_missing_not_expr_error () =
  print_endline "test_missing_not_expr_error";
  let err = get_err @@ Oiq_match_query.of_string "not" in
  assert (err = `Error (Some { Oiq_match_query.lnum = 1; offset = 0 }, "not", "MISSING_NOT_EXPR"))

let test_missing_rhs_binary_expr_and_error () =
  print_endline "test_missing_rh_of_binary_expr_and_error";
  let err = get_err @@ Oiq_match_query.of_string "foo and" in
  assert (err = `Error (Some { Oiq_match_query.lnum = 1; offset = 0 }, "foo and", "MISSING_RHS_AND"))

let test_missing_rhs_binary_expr_or_error () =
  print_endline "test_missing_rh_of_binary_expr_or_error";
  let err = get_err @@ Oiq_match_query.of_string "foo or" in
  assert (err = `Error (Some { Oiq_match_query.lnum = 1; offset = 0 }, "foo or", "MISSING_RHS_OR"))

let test_missing_not_sure_error () =
  print_endline "test_missing_not_sure_error";
  let err = get_err @@ Oiq_match_query.of_string "(foo" in
  assert (
    err = `Error (Some { Oiq_match_query.lnum = 1; offset = 0 }, "(foo", "MISSING_EXPR_OR_RPAREN"))

let test_missing_rhs_binary_expr_equals_error () =
  print_endline "test_missing_rhs_binary_expr_equals_error";
  let err = get_err @@ Oiq_match_query.of_string "foo=" in
  assert (
    err = `Error (Some { Oiq_match_query.lnum = 1; offset = 0 }, "foo=", "MISSING_EXPR_RHS_EQUALS"))

let test_unexpected_rparen_error () =
  print_endline "test_unexpected_rparen_error";
  let err = get_err @@ Oiq_match_query.of_string ")" in
  assert (err = `Error (None, ")", "UNEXPECTED_RPAREN"))

let test_expected_op_found_string_error () =
  print_endline "test_expected_op_found_string_error";
  let err = get_err @@ Oiq_match_query.of_string "foo and bar baz" in
  assert (
    err
    = `Error
        ( Some { Oiq_match_query.lnum = 1; offset = 0 },
          "foo and bar baz",
          "EXPECTED_OP_FOUND_STRING" ))

let test_expected_op_found_string_error_2 () =
  print_endline "test_expected_op_found_string_error_2";
  let err = get_err @@ Oiq_match_query.of_string "foo bar" in
  assert (
    err
    = `Error (Some { Oiq_match_query.lnum = 1; offset = 0 }, "foo bar", "EXPECTED_OP_FOUND_STRING"))

let () =
  test_empty_query ();
  test_empty_set_and_empty_query ();
  test_key_match ();
  test_key_fail ();
  test_key_value_match ();
  test_compact_key_value_match ();
  test_key_value_and_match ();
  test_key_value_and_fail ();
  test_key_value_or_both_match ();
  test_key_value_or_one_match ();
  test_not_key_match ();
  test_not_key_fail ();
  test_not_key_value_match ();
  test_not_key_value_fail ();
  test_single_quote_key_match ();
  test_double_quote_key_match ();
  test_and_precedence_match ();
  test_not_precedence_match ();
  test_and_precedence_parens_equal ();
  test_not_precedence_parens_equal ();
  test_not_precedence_parens_equal_1 ();
  test_simple_paren_expr_match ();
  test_unmatching_paren_error ();
  test_missing_not_expr_error ();
  test_missing_rhs_binary_expr_and_error ();
  test_missing_rhs_binary_expr_or_error ();
  test_missing_not_sure_error ();
  test_missing_rhs_binary_expr_equals_error ();
  test_unexpected_rparen_error ();
  test_expected_op_found_string_error ();
  test_expected_op_found_string_error_2 ()
