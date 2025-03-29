%token <string> STRING
%token LPAREN RPAREN
%token AND OR NOT
%token EQUAL
%token EOF

%left OR
%left AND
%left NOT

%{
    open Oiq_match_query_parser_value
%}

%start <Oiq_match_query_parser_value.t option> start

%on_error_reduce expr

%%

start:
  | EOF
    { None }
  | e = expr; EOF
    { Some e }

binary_op:
  | e1 = expr; AND; e2 = expr
    { And (e1, e2) }
  | e1 = expr; OR; e2 = expr
    { Or (e1, e2) }
  | key = STRING; EQUAL; v = STRING
    { Equals (key, v) }
;

expr:
  | NOT; e = expr
    { Not e }
  | LPAREN; e = expr; RPAREN
    { e }
  | e = binary_op
    { e }
  | s = STRING
    { Key s }
;    
