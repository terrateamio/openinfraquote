module Resource = struct
  type t = {
    provider : string;
    resource_type : string;
    name : string;
    data : Yojson.Safe.t;
  }
end
