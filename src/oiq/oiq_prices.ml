module Price = struct
  type t =
    | Per_hour of float
    | Per_operation of float
    | Reserved of float
  [@@deriving eq]

  let to_yojson t = raise (Failure "POOP")

  let of_yojson json =
    let module P = struct
      type t = {
        usd : string; [@key "USD"]
        unit : string;
      }
      [@@deriving of_yojson { strict = false }]
    end in
    CCResult.map
      (function
        | { P.usd; unit = "hr" } -> Per_hour (CCFloat.of_string_exn usd)
        | { P.usd; unit = "op" } -> Per_operation (CCFloat.of_string_exn usd)
        | _ -> raise (Failure "MEOW"))
      (P.of_yojson json)
end

module Product = struct
  type t = {
    service : string;
    product_family : string;
    match_set_str : string;
    price_info : Price.t list;
  }
  [@@deriving yojson, eq]

  let of_row row =
    match row with
    | [ service; product_family; match_set_str; price_info ] ->
        let price_info =
          let json = Yojson.Safe.from_string price_info in
          let module P = struct
            type t = Price.t list [@@deriving of_yojson { strict = false }]
          end in
          Printf.printf "%s" price_info;
          match P.of_yojson json with
          | Ok items -> items
          | Error e -> raise (Failure e)
        in
        { service; product_family; match_set_str; price_info }
    | _ -> raise (Failure "MEEEEEEOOOOOOOW")

  let to_match_set t = CCResult.get_exn @@ Oiq_match_set.of_string t.match_set_str
end
