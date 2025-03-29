type pos = {
  lnum : int;
  offset : int;
}
[@@deriving show]

type err = [ `Error of pos option * string * string ] [@@deriving show]

type t = {
  q : Oiq_match_query_parser_value.t option;
  s : string;
}
[@@deriving show]

let state checkpoint =
  let module I = Oiq_match_query_parser.MenhirInterpreter in
  let module S = MenhirLib.General in
  match I.top checkpoint with
  | None -> 0
  | Some (I.Element (s, _, _, _)) -> I.number s

let position checkpoint =
  let module I = Oiq_match_query_parser.MenhirInterpreter in
  let module S = MenhirLib.General in
  match I.top checkpoint with
  | None -> None
  | Some (I.Element (_, _, { Lexing.pos_lnum; pos_bol; _ }, _)) ->
      Some { lnum = pos_lnum; offset = pos_bol }

let rec loop next_token lexbuf checkpoint =
  let module I = Oiq_match_query_parser.MenhirInterpreter in
  match checkpoint with
  | I.InputNeeded _ ->
      let token = next_token () in
      let checkpoint = I.offer checkpoint token in
      loop next_token lexbuf checkpoint
  | I.Shifting (_, _, _) | I.AboutToReduce (_, _) ->
      let checkpoint = I.resume checkpoint in
      loop next_token lexbuf checkpoint
  | I.HandlingError env ->
      Error
        (try (position env, Oiq_match_query_parser_errors.message (state env))
         with Not_found -> (position env, CCInt.to_string (state env)))
  | I.Accepted ast -> Ok ast
  | I.Rejected -> assert false

let of_string s =
  let lexbuf = Sedlexing.Utf8.from_string s in
  let lexer = Sedlexing.with_tokenizer Oiq_match_query_lexer.token lexbuf in
  match
    loop
      lexer
      lexbuf
      (Oiq_match_query_parser.Incremental.start (fst @@ Sedlexing.lexing_positions lexbuf))
  with
  | Ok q -> Ok { q; s }
  | Error (pos, err) -> Error (`Error (pos, s, CCString.trim err))

let rec eval' ms =
  let module V = Oiq_match_query_parser_value in
  function
  | V.And (e1, e2) -> eval' ms e1 && eval' ms e2
  | V.Equals (k, v) -> Oiq_match_set.subset ~super:ms (Oiq_match_set.of_list [ (k, v) ])
  | V.Key k -> CCOption.is_some @@ Oiq_match_set.find_by_key k ms
  | V.Not e -> not (eval' ms e)
  | V.Or (e1, e2) -> eval' ms e1 || eval' ms e2

let eval ms = function
  | { q = None; _ } -> true
  | { q = Some v; _ } -> eval' ms v

let to_string { s; _ } = s
