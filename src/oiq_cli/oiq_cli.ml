module Cli = struct
  module C = Cmdliner

  (* <resource_file> <resource_file> ... *)
  let resource_file =
    let docv = "RESOURCE_FILE" in
    let doc = "The input file that describes the infrastructure: eg. plan or state file." in
    C.Arg.(non_empty & pos_all file [] & info [] ~docv ~doc)

  (* -p | --pricingsheet <dirpath> *)
  let pricesheet =
    let docv = "PRICING_SHEET" in
    let doc = "Path to the pricing CSV." in
    C.Arg.(required & opt (some file) None & info [ "p"; "pricesheet" ] ~docv ~doc)

  (* -o | --output-path <filepath> *)
  let output =
    let docv = "OUTPUT_FILE" in
    let doc = "The path for writing matched price info, stdout if not specified." in
    C.Arg.(value & opt (some string) None & info [ "o"; "output" ] ~docv ~doc)

  let output_format =
    let docv = "FORMAT" in
    let doc = "Format of output (text or json)." in
    C.Arg.(
      value
      & opt (enum [ ("text", `Text); ("json", `Json) ]) `Text
      & info [ "f"; "format" ] ~docv ~doc)

  let match_query =
    let docv = "QUERY" in
    let doc =
      "Specify a match query.  Can be provided multiple times and at least one must match.  A \
       match is only performed if the keys specified in the match query exist in the matched \
       product.  For example, if the match query is 'region=us-east-1', this will be tested \
       against products which have a region in their pricing.  Use '&' to specify multiple entries \
       in a single match query that must all match.  For example to match region us-east-1 for \
       type aws_instance: 'region=us-east-1 & type=aws_instance'"
    in
    C.Arg.(value & opt_all string [] & info [ "mq"; "match-query" ] ~docv ~doc)

  let region =
    let docv = "REGION" in
    let doc = "Specify a region to price against.  This is sugar for --mq 'region=<some_region>'" in
    C.Arg.(value & opt (some string) None & info [ "region" ] ~docv ~doc)

  let match_cmd f =
    let doc = "Match resource to pricing rows." in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v (C.Cmd.info "match" ~doc ~exits) C.Term.(const f $ pricesheet $ resource_file $ output)

  let usage =
    let docv = "USAGE_FILE" in
    let doc = "File describing usage of specific resources to be used in pricing." in
    C.Arg.(value & opt (some file) None & info [ "u"; "usage" ] ~docv ~doc)

  let input =
    let docv = "INPUT_FILE" in
    let doc = "Path to file generated in 'match', stdin if not specified." in
    C.Arg.(value & opt (some file) None & info [ "i"; "input" ] ~docv ~doc)

  let price_cmd f =
    let doc = "Price a match." in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v
      (C.Cmd.info "price" ~doc ~exits)
      C.Term.(const f $ usage $ input $ output_format $ match_query $ region)
end

let reporter ppf =
  let report src level ~over k msgf =
    let k _ =
      over ();
      k ()
    in
    let with_stamp h tags k ppf fmt =
      let time = Unix.gettimeofday () in
      let time_str = ISO8601.Permissive.string_of_datetime time in
      Format.kfprintf k ppf ("[%s] %a @[" ^^ fmt ^^ "@]@.") time_str Logs.pp_header (level, h)
    in
    msgf @@ fun ?header ?tags fmt -> with_stamp header tags k ppf fmt
  in
  { Logs.report }

let setup_log () =
  Logs.set_reporter (reporter Format.err_formatter);
  Logs.set_level (Some Logs.Debug)

let match_ pricesheet resource_files output_path =
  setup_log ();
  match
    Oiq.match_
      ~pricesheet
      ~resource_files
      ~output:
        (match output_path with
        | Some path -> open_out path
        | None -> stdout)
  with
  | Ok () -> ()
  | Error err ->
      Logs.err (fun m -> m "%a" Oiq.pp_match_err err);
      exit 1

let price usage input output_format match_query region =
  setup_log ();
  let with_input f =
    match input with
    | Some fname -> CCIO.with_in fname f
    | None -> f stdin
  in
  let maybe_with_usage f =
    match usage with
    | Some fname -> CCIO.with_in fname (fun io -> f (Some io))
    | None -> f None
  in
  let match_query =
    CCList.map
      (fun s ->
        s
        |> CCString.split_on_char '&'
        |> CCList.map CCString.trim
        |> CCList.map (fun s ->
               match CCString.Split.left ~by:"=" s with
               | Some (key, v) -> (key, v)
               | None -> raise (Failure "nyi"))
        |> Oiq_match_set.of_list)
      (match_query @ CCOption.map_or ~default:[] (fun region -> [ "region=" ^ region ]) region)
  in
  match
    with_input (fun input ->
        maybe_with_usage (fun usage -> Oiq.price ?usage ~match_query ~input ()))
  with
  | Ok priced -> (
      match output_format with
      | `Text -> print_endline @@ Oiq_pricer.pretty_to_string priced
      | `Json -> print_endline @@ Yojson.Safe.pretty_to_string @@ Oiq_pricer.to_yojson priced)
  | Error err ->
      Logs.err (fun m -> m "%a" Oiq.pp_price_err err);
      exit 1

let () =
  let info = Cmdliner.Cmd.info "oiq" in
  exit @@ Cmdliner.Cmd.eval @@ Cmdliner.Cmd.group info [ Cli.match_cmd match_; Cli.price_cmd price ]
