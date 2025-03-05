module Cli = struct
  module C = Cmdliner

  (* <resource_file> <resource_file> ... *)
  let resource_file = 
    let docv = "RESOURCE_FILE" in
    let doc = "The input file that describes the infrastructure: eg. plan or state file." in
    C.Arg.(non_empty & pos_all string [] & info [] ~docv ~doc)

  (* -p | --pricing-root <dirpath> *)
  let pricing_root = 
    let docv = "PRICING_ROOT" in
    let doc = "The top of the directory that stores the pricing CSVs." in
    C.Arg.(value & opt (some string) None & info ["p"; "pricing-root"] ~docv ~doc)

  let price_cmd f =
    let doc = "Pricing commands" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v (C.Cmd.info "price" ~doc ~exits)
      C.Term.(const f $ pricing_root $ resource_file)

end

let run pricing_root resource_file =
  let open Printf in
  let dir_path =
    match pricing_root with
    | Some dirpath  -> dirpath
    | None -> Sys.getenv "PWD"
  in
  let resource_file_str = String.concat ", " resource_file in
  printf "Resource file %s\n" resource_file_str;
  printf "Pricing root %s\n" dir_path;
  printf "Dev Data Root %s\n" Infraquote.data_root

let () =
  let info = Cmdliner.Cmd.info "oiq" in
  exit @@ Cmdliner.Cmd.eval @@ Cmdliner.Cmd.group info [Cli.price_cmd run]


