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
  let output_path =
    let docv = "OUTPUT_PATH" in
    let doc = "The path for writing matched price info." in
    C.Arg.(value & opt (some string) None & info [ "o"; "output-path" ] ~docv ~doc)

  let match_cmd f =
    let doc = "Price matching commands" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v
      (C.Cmd.info "match" ~doc ~exits)
      C.Term.(const f $ pricing_root $ resource_file $ output_path)
end

let run pricing_root resource_files output_path =
  Oiq.match_
    ~pricing_root
    ~resource_files
    ~output:
      (match output_path with
      | Some path -> open_out path
      | None -> stdout)

let () =
  let info = Cmdliner.Cmd.info "oiq" in
  exit @@ Cmdliner.Cmd.eval @@ Cmdliner.Cmd.group info [ Cli.match_cmd run ]
