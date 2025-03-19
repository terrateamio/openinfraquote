module Cli = struct
  module C = Cmdliner

  (* <resource_file> <resource_file> ... *)
  let resource_file =
    let docv = "RESOURCE_FILE" in
    let doc = "The input file that describes the infrastructure: eg. plan or state file." in
    C.Arg.(non_empty & pos_all file [] & info [] ~docv ~doc)

  (* -p | --pricing-root <dirpath> *)
  let pricing_root =
    let docv = "PRICING_ROOT" in
    let doc = "The top of the directory that stores the pricing CSVs." in
    C.Arg.(required & opt (some dir) None & info [ "p"; "pricing-root" ] ~docv ~doc)

  (* -o | --output-path <filepath> *)
  let output =
    let docv = "OUTPUT_FILE" in
    let doc = "The path for writing matched price info, stdout if not specified." in
    C.Arg.(value & opt (some string) None & info [ "o"; "output" ] ~docv ~doc)

  let match_cmd f =
    let doc = "Match resource to pricing rows." in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v
      (C.Cmd.info "match" ~doc ~exits)
      C.Term.(const f $ pricing_root $ resource_file $ output)

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
    C.Cmd.v (C.Cmd.info "price" ~doc ~exits) C.Term.(const f $ usage $ input)
end

let reporter ppf =
  let report src level ~over k msgf =
    let k _ =
      over ();
      k ()
    in
    let with_stamp h tags k ppf fmt =
      (* TODO: Make this use the proper Abb time *)
      let time = Unix.gettimeofday () in
      let time_str = ISO8601.Permissive.string_of_datetime time in
      Format.kfprintf k ppf ("[%s] %a @[" ^^ fmt ^^ "@]@.") time_str Logs.pp_header (level, h)
    in
    msgf @@ fun ?header ?tags fmt -> with_stamp header tags k ppf fmt
  in
  { Logs.report }

let setup_log () =
  Logs.set_reporter (reporter Format.std_formatter);
  Logs.set_level (Some Logs.Debug)

let match_ pricing_root resource_files output_path =
  setup_log ();
  match
    Oiq.match_
      ~pricing_root
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

let price usage input = raise (Failure "nyi")

let () =
  let info = Cmdliner.Cmd.info "oiq" in
  exit @@ Cmdliner.Cmd.eval @@ Cmdliner.Cmd.group info [ Cli.match_cmd match_; Cli.price_cmd price ]
