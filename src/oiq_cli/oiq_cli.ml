module Cli = struct
  let version = CCString.trim [%blob "../../version"]

  module C = Cmdliner

  (* <resource_file> <resource_file> ... *)
  let resource_file =
    let docv = "RESOURCE_FILE" in
    let doc = "The input file that describes the infrastructure: eg. plan or state file." in
    C.Arg.(non_empty & pos_all file [] & info [] ~docv ~doc)

  (* -p | --pricingsheet <dirpath> *)
  let pricesheet =
    let docv = "PRICE_SHEET" in
    let doc = "Path to the pricing CSV." in
    let env =
      let doc = "Path to pricing CSV" in
      C.Cmd.Env.info ~doc "OIQ_PRICE_SHEET"
    in
    C.Arg.(required & opt (some file) None & info [ "p"; "pricesheet" ] ~docv ~doc ~env)

  (* -o | --output-path <filepath> *)
  let output =
    let docv = "OUTPUT_FILE" in
    let doc = "The path for writing matched price info, stdout if not specified." in
    C.Arg.(value & opt (some string) None & info [ "o"; "output" ] ~docv ~doc)

  let output_format =
    let docv = "FORMAT" in
    let doc = "Format of output (summary, text, json, markdown, atlantis-comment)." in
    let env =
      let doc = "Specify output format" in
      C.Cmd.Env.info ~doc "OIQ_OUTPUT_FORMAT"
    in
    C.Arg.(
      value
      & opt
          (enum
             [
               ("summary", `Summary);
               ("text", `Text);
               ("json", `Json);
               ("markdown", `Markdown);
               ("atlantis-comment", `Atlantis_comment);
             ])
          `Summary
      & info [ "f"; "format" ] ~docv ~doc ~env)

  let match_query =
    let docv = "QUERY" in
    let doc =
      "Specify a match query.  This is applied to products prior to pricing, providing the ability \
       to remove or select specific products.  The query is tested against a product and the \
       resource it is associated with and both can be queried.  For example, to price an s3 bucket \
       named 'my_bucket' according to region us-east-1 and every other resource according to \
       us-west-1: --mq '(type = aws_s3_bucket and name = my_bucket and region = us-east-1) or (not \
       (type = aws_s3_bucket and name = my_bucket) and region=us-west-1'"
    in
    C.Arg.(value & opt (some string) None & info [ "mq"; "match-query" ] ~docv ~doc)

  let region =
    let docv = "REGION" in
    let doc =
      "Specify a region to price against.  This is sugar for --mq 'not region or \
       region=<some_region>'"
    in
    let env =
      let doc = "Specify region to price against" in
      C.Cmd.Env.info ~doc "OIQ_REGION"
    in
    C.Arg.(value & opt_all string [] & info [ "region" ] ~docv ~doc ~env)

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

  let print_default_usage_cmd f =
    let doc = "Print default usage file." in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v (C.Cmd.info "print-default-usage" ~doc ~exits) C.Term.(const f $ const ())
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

let price usage input output_format match_query regions =
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
  let region_query =
    if CCList.is_empty regions then None
    else
      Some
        ("not region or ("
        ^ (CCString.concat " or " @@ CCList.map (fun r -> "region=" ^ r) regions)
        ^ ")")
  in
  let match_query =
    match (region_query, match_query) with
    | Some region_query, Some match_query ->
        Some (Printf.sprintf "(%s) and (%s)" region_query match_query)
    | Some q, None | None, Some q -> Some q
    | None, None -> None
  in
  match
    let open CCResult.Infix in
    CCResult.opt_map Oiq_match_query.of_string match_query
    >>= fun match_query ->
    with_input (fun input ->
        maybe_with_usage (fun usage -> Oiq.price ?usage ?match_query ~input ()))
  with
  | Ok priced -> (
      match output_format with
      | `Summary -> print_endline @@ Oiq_pricer.to_summary_string priced
      | `Text -> print_endline @@ Oiq_pricer.pretty_to_string priced
      | `Json -> print_endline @@ Yojson.Safe.pretty_to_string @@ Oiq_pricer.to_yojson priced
      | `Markdown -> print_endline @@ Oiq_pricer.to_markdown_string priced
      | `Atlantis_comment -> print_endline @@ Oiq_pricer.to_atlantis_comment_string priced)
  | Error (#Oiq_match_query.err as err) ->
      Logs.err (fun m -> m "%a" Oiq_match_query.pp_err err);
      exit 1
  | Error (#Oiq.price_err as err) ->
      Logs.err (fun m -> m "%a" Oiq.pp_price_err err);
      exit 1

let print_default_usage () =
  let default = Oiq_usage.default () in
  print_endline @@ Yojson.Safe.pretty_to_string @@ Oiq_usage.to_yojson default

let () =
  let info = Cmdliner.Cmd.info ~version:Cli.version "oiq" in
  exit
  @@ Cmdliner.Cmd.eval
  @@ Cmdliner.Cmd.group
       info
       [
         Cli.match_cmd match_; Cli.price_cmd price; Cli.print_default_usage_cmd print_default_usage;
       ]
