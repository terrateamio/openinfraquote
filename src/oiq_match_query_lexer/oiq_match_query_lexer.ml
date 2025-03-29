exception Premature_end_of_string of string
exception Unexpected_symbol of string

module T = Oiq_match_query_parser

let identifier_key = [%sedlex.regexp? Plus (Compl (Chars " '\"()="))]
let identifier_value = [%sedlex.regexp? Plus (Compl (Chars " '\"()"))]

let rec string stop b buf =
  match%sedlex buf with
  | '\\', any ->
      Buffer.add_char b (String.get (Sedlexing.Utf8.lexeme buf) 1);
      string stop b buf
  | Chars "'\"" -> (
      match Sedlexing.Utf8.lexeme buf with
      | "\"" when stop = '"' -> T.STRING (Buffer.contents b)
      | "'" when stop = '\'' -> T.STRING (Buffer.contents b)
      | s ->
          Buffer.add_string b s;
          string stop b buf)
  | any ->
      Buffer.add_string b (Sedlexing.Utf8.lexeme buf);
      string stop b buf
  | _ -> raise (Premature_end_of_string (Buffer.contents b))

let rec token buf =
  match%sedlex buf with
  | '(' -> T.LPAREN
  | ')' -> T.RPAREN
  | '"' ->
      let b = Buffer.create 10 in
      string '"' b buf
  | '\'' ->
      let b = Buffer.create 10 in
      string '\'' b buf
  | '=' -> T.EQUAL
  | Plus white_space -> token buf
  | identifier_key -> (
      match Sedlexing.Utf8.lexeme buf with
      | "and" -> T.AND
      | "or" -> T.OR
      | "not" -> T.NOT
      | str -> T.STRING str)
  | eof -> T.EOF
  | _ -> raise (Unexpected_symbol (Sedlexing.Utf8.lexeme buf))
