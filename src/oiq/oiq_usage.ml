module Usage = struct
  let range_of_yojson json =
    match [%of_yojson: int] json with
    | Ok v -> Ok { Oiq_range.min = v; max = v }
    | Error _ -> [%of_yojson: int Oiq_range.t] json

  let default = { Oiq_range.min = 0; max = 0 }

  type t = {
    time : int Oiq_range.t; [@default default] [@of_yojson range_of_yojson]
    operations : int Oiq_range.t; [@default default] [@of_yojson range_of_yojson]
    data : int Oiq_range.t; [@default default] [@of_yojson range_of_yojson]
  }
  [@@deriving yojson, show]

  let time t = t.time
  let operations t = t.operations
  let data t = t.data
  let make range = { time = default; operations = default; data = range }

  (** Multiply all usage values by a factor *)
  let multiply factor t =
    {
      time = { Oiq_range.min = t.time.Oiq_range.min * factor; max = t.time.Oiq_range.max * factor };
      operations =
        { Oiq_range.min = t.operations.Oiq_range.min * factor; max = t.operations.Oiq_range.max * factor };
      data = { Oiq_range.min = t.data.Oiq_range.min * factor; max = t.data.Oiq_range.max * factor };
    }
end

(** Reference-based usage multiplier.
    Allows usage to be multiplied by a value from a referenced resource.

    For example, an ECS service's vCPU usage can be multiplied by the
    task definition's CPU value:
    {[
      {
        "ref_attr": "task_definition",
        "value_path": "values.cpu",
        "divisor": 1024
      }
    ]}

    This would multiply the base usage by (task_definition.values.cpu / 1024). *)
module Ref_multiplier = struct
  type t = {
    (** The attribute name that references another resource (e.g., "task_definition") *)
    ref_attr : string;
    (** The path within the referenced resource to get the value (e.g., "values.cpu") *)
    value_path : string;
    (** Optional divisor to apply to the value (e.g., 1024 to convert CPU units to vCPU) *)
    divisor : int; [@default 1]
  }
  [@@deriving yojson, show]

  (** Look up the multiplier value from a resource using reference info.
      Returns the multiplier value (after applying divisor), or 0 if not found.
      Returning 0 ensures no charge when the referenced value doesn't exist
      (e.g., no block device storage charge when launch template has no block devices). *)
  let resolve (refs : Oiq_tf.Refs.t) (resource_address : string) (t : t) : int =
    let ref_path = t.ref_attr ^ "." ^ t.value_path in
    match Oiq_tf.Refs.lookup_ref_value refs resource_address ref_path with
    | Some value_str -> (
        match CCInt.of_string value_str with
        | Some value -> CCInt.max 1 (value / t.divisor)
        | None -> 0)
    | None -> 0
end

(** Value-based usage multiplier.
    Allows usage to be multiplied by a value from the resource's own attributes.

    For example, an ECS service's usage can be multiplied by its desired_count:
    {[
      {
        "value_path": "values.desired_count",
        "divisor": 1
      }
    ]}

    This would multiply the base usage by the resource's desired_count value. *)
module Value_multiplier = struct
  type t = {
    (** The path within the resource to get the value (e.g., "values.desired_count") *)
    value_path : string;
    (** Optional divisor to apply to the value (default 1) *)
    divisor : int; [@default 1]
  }
  [@@deriving yojson, show]

  (** Look up the multiplier value from the resource's own match set.
      Returns the multiplier value (after applying divisor), or 1 if not found. *)
  let resolve (resource_ms : Oiq_match_set.t) (t : t) : int =
    match Oiq_match_set.find_by_key t.value_path resource_ms with
    | Some (_, value_str) -> (
        match CCInt.of_string value_str with
        | Some value -> CCInt.max 1 (value / t.divisor)
        | None -> 1)
    | None -> 1
end

(** Formula-based usage multiplier.
    Allows usage to be multiplied by a computed value from the resource's attributes.

    For example, an ElastiCache replication group's node count can be calculated as:
    {[
      {
        "formula": "(values.num_node_groups * values.replicas_per_node_group) + values.num_node_groups"
      }
    ]}

    This would multiply the base usage by the computed node count.

    Supported operators: +, -, *, /
    Supported operands: integers and field references (e.g., values.field_name) *)
module Formula_multiplier = struct
  type t = {
    (** The formula to evaluate (e.g., "(values.x * values.y) + values.x") *)
    formula : string;
    (** Optional divisor to apply to the result (default 1) *)
    divisor : int; [@default 1]
  }
  [@@deriving yojson, show]

  (** Token type for the formula lexer *)
  type token =
    | INT of int
    | IDENT of string
    | PLUS
    | MINUS
    | STAR
    | SLASH
    | LPAREN
    | RPAREN
    | EOF

  (** Tokenize a formula string *)
  let tokenize (s : string) : token list =
    let len = String.length s in
    let rec skip_ws i = if i < len && (s.[i] = ' ' || s.[i] = '\t') then skip_ws (i + 1) else i in
    let rec read_int acc i =
      if i < len && s.[i] >= '0' && s.[i] <= '9' then
        read_int ((acc * 10) + Char.code s.[i] - Char.code '0') (i + 1)
      else (INT acc, i)
    in
    let rec read_ident acc i =
      if i < len && (s.[i] >= 'a' && s.[i] <= 'z' || s.[i] >= 'A' && s.[i] <= 'Z' ||
                     s.[i] >= '0' && s.[i] <= '9' || s.[i] = '_' || s.[i] = '.') then
        read_ident (acc ^ String.make 1 s.[i]) (i + 1)
      else (IDENT acc, i)
    in
    let rec go acc i =
      let i = skip_ws i in
      if i >= len then List.rev (EOF :: acc)
      else
        let c = s.[i] in
        if c >= '0' && c <= '9' then
          let tok, next = read_int 0 i in
          go (tok :: acc) next
        else if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' then
          let tok, next = read_ident "" i in
          go (tok :: acc) next
        else
          match c with
          | '+' -> go (PLUS :: acc) (i + 1)
          | '-' -> go (MINUS :: acc) (i + 1)
          | '*' -> go (STAR :: acc) (i + 1)
          | '/' -> go (SLASH :: acc) (i + 1)
          | '(' -> go (LPAREN :: acc) (i + 1)
          | ')' -> go (RPAREN :: acc) (i + 1)
          | _ -> go acc (i + 1) (* skip unknown chars *)
    in
    go [] 0

  (** AST for arithmetic expressions *)
  type expr =
    | Num of int
    | Var of string
    | Add of expr * expr
    | Sub of expr * expr
    | Mul of expr * expr
    | Div of expr * expr

  (** Parse tokens into an AST using recursive descent *)
  let parse (tokens : token list) : expr option =
    let tokens = ref tokens in
    let peek () = match !tokens with t :: _ -> t | [] -> EOF in
    let advance () = match !tokens with _ :: rest -> tokens := rest | [] -> () in

    let rec parse_primary () =
      match peek () with
      | INT n ->
          advance ();
          Some (Num n)
      | IDENT s ->
          advance ();
          Some (Var s)
      | LPAREN ->
          advance ();
          let e = parse_expr () in
          (match peek () with RPAREN -> advance () | _ -> ());
          e
      | _ -> None

    and parse_factor () = parse_primary ()

    and parse_term () =
      match parse_factor () with
      | None -> None
      | Some left ->
          let rec loop left =
            match peek () with
            | STAR ->
                advance ();
                (match parse_factor () with
                 | Some right -> loop (Mul (left, right))
                 | None -> Some left)
            | SLASH ->
                advance ();
                (match parse_factor () with
                 | Some right -> loop (Div (left, right))
                 | None -> Some left)
            | _ -> Some left
          in
          loop left

    and parse_expr () =
      match parse_term () with
      | None -> None
      | Some left ->
          let rec loop left =
            match peek () with
            | PLUS ->
                advance ();
                (match parse_term () with
                 | Some right -> loop (Add (left, right))
                 | None -> Some left)
            | MINUS ->
                advance ();
                (match parse_term () with
                 | Some right -> loop (Sub (left, right))
                 | None -> Some left)
            | _ -> Some left
          in
          loop left
    in
    parse_expr ()

  (** Evaluate an expression against a match set *)
  let rec eval (resource_ms : Oiq_match_set.t) (e : expr) : int option =
    match e with
    | Num n -> Some n
    | Var s -> (
        match Oiq_match_set.find_by_key s resource_ms with
        | Some (_, value_str) -> CCInt.of_string value_str
        | None -> None)
    | Add (e1, e2) -> (
        match (eval resource_ms e1, eval resource_ms e2) with
        | Some v1, Some v2 -> Some (v1 + v2)
        | _ -> None)
    | Sub (e1, e2) -> (
        match (eval resource_ms e1, eval resource_ms e2) with
        | Some v1, Some v2 -> Some (v1 - v2)
        | _ -> None)
    | Mul (e1, e2) -> (
        match (eval resource_ms e1, eval resource_ms e2) with
        | Some v1, Some v2 -> Some (v1 * v2)
        | _ -> None)
    | Div (e1, e2) -> (
        match (eval resource_ms e1, eval resource_ms e2) with
        | Some v1, Some v2 when v2 <> 0 -> Some (v1 / v2)
        | _ -> None)

  (** Resolve the formula to a multiplier value.
      Returns the computed value (after applying divisor), or 1 if evaluation fails. *)
  let resolve (resource_ms : Oiq_match_set.t) (t : t) : int =
    let tokens = tokenize t.formula in
    match parse tokens with
    | Some ast -> (
        match eval resource_ms ast with
        | Some value -> CCInt.max 1 (value / t.divisor)
        | None -> 1)
    | None -> 1
end

(** Reference-based product filter.
    Allows filtering products based on a value from a referenced resource.

    For example, an ASG's instance pricing should only match the instance_type
    from the referenced launch template:
    {[
      {
        "ref_attr": "values.launch_template.0.id",
        "pricing_key": "instance_type",
        "value_path": "values.instance_type"
      }
    ]}

    This would filter products where pricing_match_set.instance_type equals
    the instance_type from the referenced launch template. *)
module Ref_filter = struct
  type t = {
    (** The attribute path that references another resource (e.g., "values.launch_template.0.id") *)
    ref_attr : string;
    (** The key in pricing_match_set to filter on (e.g., "instance_type") *)
    pricing_key : string;
    (** The path within the referenced resource to get the expected value (e.g., "values.instance_type") *)
    value_path : string;
  }
  [@@deriving yojson, show]

  (** Look up the expected value from the referenced resource.
      Returns Some value if found, None otherwise. *)
  let resolve (refs : Oiq_tf.Refs.t) (resource_address : string) (t : t) : string option =
    let ref_path = t.ref_attr ^ "." ^ t.value_path in
    Oiq_tf.Refs.lookup_ref_value refs resource_address ref_path

  (** Check if a product matches the ref filter.
      Returns true if the product's pricing_key matches the referenced value,
      or if the reference couldn't be resolved (fail open). *)
  let matches (refs : Oiq_tf.Refs.t) (resource_address : string) (pricing_ms : Oiq_match_set.t) (t : t) : bool =
    match resolve refs resource_address t with
    | Some expected_value -> (
        match Oiq_match_set.find_by_key t.pricing_key pricing_ms with
        | Some (_, actual_value) -> CCString.equal expected_value actual_value
        | None -> false)
    | None -> true (* fail open if reference not found *)
end

(** Reference-based usage entry matcher.
    Allows a usage entry to conditionally apply based on a value from
    a referenced resource.

    For example, an ASG's dedicated tenancy pricing should only apply if
    the referenced launch template has placement.tenancy = "dedicated". *)
module Ref_match = struct
  type t = {
    (** The attribute path that references another resource (e.g., "launch_template.0.id") *)
    ref_attr : string;
    (** The path within the referenced resource to check (e.g., "values.placement.0.tenancy") *)
    value_path : string;
    (** The expected value to match (e.g., "dedicated") *)
    expected_value : string;
    (** If true, match when the value is NOT present or NOT equal (default false) *)
    negate : bool; [@default false]
  }
  [@@deriving yojson, show]

  (** Check if the usage entry should apply based on the referenced resource's value.
      Returns true if:
      - negate=false and value matches expected_value
      - negate=true and value is missing or doesn't match expected_value *)
  let matches (refs : Oiq_tf.Refs.t) (resource_address : string) (t : t) : bool =
    let ref_path = t.ref_attr ^ "." ^ t.value_path in
    match Oiq_tf.Refs.lookup_ref_value refs resource_address ref_path with
    | Some actual_value ->
        let value_matches = CCString.equal actual_value t.expected_value in
        if t.negate then not value_matches else value_matches
    | None ->
        (* Value not found - if negated, this counts as a match *)
        t.negate
end

module Entry = struct
  module P = struct
    type 'a t = {
      description : string;
      divisor : int option; [@default None]
      match_query : string;
      usage : 'a;
      ref_multiplier : Ref_multiplier.t option; [@default None]
      value_multiplier : Value_multiplier.t option; [@default None]
      formula_multiplier : Formula_multiplier.t option; [@default None]
      ref_filter : Ref_filter.t option; [@default None]
      ref_match : Ref_match.t option; [@default None]
    }
    [@@deriving yojson]
  end

  type accessor = {
    get : Usage.t -> int Oiq_range.t;
    set : int Oiq_range.t -> Usage.t -> Usage.t;
  }

  type 'a t = {
    description : string;
    divisor : int option;
    match_query : Oiq_match_query.t;
    usage : 'a;
    ref_multiplier : Ref_multiplier.t option;
    value_multiplier : Value_multiplier.t option;
    formula_multiplier : Formula_multiplier.t option;
    ref_filter : Ref_filter.t option;
    ref_match : Ref_match.t option;
  }
  [@@deriving show]

  let make ?divisor ?ref_multiplier ?value_multiplier ?formula_multiplier ?ref_filter ?ref_match ~description ~match_query ~usage () =
    { description; divisor; match_query; usage; ref_multiplier; value_multiplier; formula_multiplier; ref_filter; ref_match }

  let usage t = t.usage
  let with_usage usage t = { t with usage }
  let match_query t = t.match_query
  let description t = t.description
  let divisor t = t.divisor
  let ref_multiplier t = t.ref_multiplier
  let value_multiplier t = t.value_multiplier
  let formula_multiplier t = t.formula_multiplier
  let ref_filter t = t.ref_filter
  let ref_match t = t.ref_match

  let bound_to_usage_amount accessor { Oiq_range.min; max } t =
    match accessor.get t.usage with
    | { Oiq_range.max = usage_max; _ } when usage_max < min ->
        (* The usage described in this entry does not overlap with the usage
           amount passed in. *)
        None
    | { Oiq_range.min = usage_min; max = usage_max } ->
        let diff = max - min in
        let consumption = usage_max - min in
        Some
          {
            t with
            usage =
              accessor.set
                (Oiq_range.make
                   ~min:(CCInt.max 0 (CCInt.min usage_min max - min))
                   ~max:(CCInt.min consumption diff))
                t.usage;
          }

  let time =
    { get = (fun { Usage.time; _ } -> time); set = (fun time usage -> { usage with Usage.time }) }

  let operations =
    {
      get = (fun { Usage.operations; _ } -> operations);
      set = (fun operations usage -> { usage with Usage.operations });
    }

  let data =
    { get = (fun { Usage.data; _ } -> data); set = (fun data usage -> { usage with Usage.data }) }

  let to_yojson usage_to_yojson { usage; match_query; description; divisor; ref_multiplier; value_multiplier; formula_multiplier; ref_filter; ref_match } =
    P.to_yojson
      usage_to_yojson
      { P.description; usage; match_query = Oiq_match_query.to_string match_query; divisor; ref_multiplier; value_multiplier; formula_multiplier; ref_filter; ref_match }

  let of_yojson usage_of_yojson json =
    let open CCResult.Infix in
    P.of_yojson usage_of_yojson json
    >>= fun { P.description; match_query; usage; divisor; ref_multiplier; value_multiplier; formula_multiplier; ref_filter; ref_match } ->
    CCResult.map_err (fun (#Oiq_match_query.err as err) -> Oiq_match_query.show_err err)
    @@ Oiq_match_query.of_string match_query
    >>= fun match_query -> Ok { description; match_query; usage; divisor; ref_multiplier; value_multiplier; formula_multiplier; ref_filter; ref_match }
end

type entry = {
  description : string;
  divisor : int option; [@default None]
  match_query : string;
  usage : Usage.t option; [@default None]
  ref_multiplier : Ref_multiplier.t option; [@default None]
  value_multiplier : Value_multiplier.t option; [@default None]
  formula_multiplier : Formula_multiplier.t option; [@default None]
  ref_filter : Ref_filter.t option; [@default None]
  ref_match : Ref_match.t option; [@default None]
}
[@@deriving of_yojson]

let defaults =
  CCList.map (fun { description; divisor; match_query; usage; ref_multiplier; value_multiplier; formula_multiplier; ref_filter; ref_match } ->
      {
        Entry.description;
        divisor;
        match_query = CCResult.get_exn @@ Oiq_match_query.of_string match_query;
        usage;
        ref_multiplier;
        value_multiplier;
        formula_multiplier;
        ref_filter;
        ref_match;
      })
  @@ CCResult.get_or_failwith
  @@ [%of_yojson: entry list]
  @@ Yojson.Safe.from_string [%blob "../../files/usage.json"]

type of_channel_err = [ `Usage_file_err of string ] [@@deriving show]
type t = { entries : Usage.t option Entry.t list }

let default () = { entries = defaults }

let of_channel in_chan =
  let open CCResult.Infix in
  let json =
    try Ok (Yojson.Safe.from_channel in_chan)
    with Yojson.Json_error msg -> Error (`Usage_file_err msg)
  in
  json
  >>= fun json ->
  CCResult.map_err
    (fun msg -> `Usage_file_err msg)
    ([%of_yojson: entry list] json
    >>= fun entries ->
    CCResult.map_l
      (fun { description; divisor; match_query; usage; ref_multiplier; value_multiplier; formula_multiplier; ref_filter; ref_match } ->
        CCResult.map_err (fun (#Oiq_match_query.err as err) -> Oiq_match_query.show_err err)
        @@ Oiq_match_query.of_string match_query
        >>= fun match_query -> Ok { Entry.description; divisor; match_query; usage; ref_multiplier; value_multiplier; formula_multiplier; ref_filter; ref_match })
      entries
    >>= fun entries -> Ok { entries = entries @ defaults })

let match_ ms t =
  CCList.find_opt (fun { Entry.match_query; _ } -> Oiq_match_query.eval ms match_query) t.entries

let to_yojson { entries } = [%to_yojson: Usage.t option Entry.t list] entries
