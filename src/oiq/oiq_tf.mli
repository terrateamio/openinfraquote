val type_ : Yojson.Safe.t -> [ `Plan | `State | `Unknown ]

module Resource : sig
  type t [@@deriving yojson]

  val address : t -> string
  val name : t -> string
  val type_ : t -> string
  val to_match_set : t -> Oiq_match_set.t
end

module Plan : sig
  type change =
    [ `Noop
    | `Add
    | `Remove
    ]

  type err = [ `Invalid_plan of string ] [@@deriving show]
  type t

  val of_yojson : Yojson.Safe.t -> (t, [> err ]) result
  val resources : t -> (Resource.t * change) list
end

module State : sig
  type err = [ `Invalid_state of string ] [@@deriving show]
  type t

  val of_yojson : Yojson.Safe.t -> (t, [> err ]) result
  val resources : t -> Resource.t list
end

(** [Refs] provides reference resolution for terraform plans.

    In terraform, resources can reference other resources. For example, an ECS service
    references a task definition to get memory and CPU values. This module parses the
    [configuration] block from terraform plan JSON to extract these references and
    provides functions to resolve them. *)
module Refs : sig
  type t

  (** An empty reference context with no resources or references. *)
  val empty : t

  (** Build a reference context from plan JSON and a list of resources.
      The resources should be the already-parsed resources from planned_values.
      This parses the [configuration] block to extract reference information. *)
  val of_yojson : Yojson.Safe.t -> Resource.t list -> t

  (** Build a reference context from a list of resources only (no configuration).
      This is useful for state files which don't have a configuration block. *)
  val of_resources : Resource.t list -> t

  (** Add reference entries to an existing Refs context.
      Each entry is (resource_address, attribute, list_of_referenced_addresses). *)
  val add_references : (string * string * string list) list -> t -> t

  (** Look up a resource by its address. *)
  val find_resource : t -> string -> Resource.t option

  (** Get the list of addresses that a resource attribute references.
      [get_references refs "aws_ecs_service.svc1" "task_definition"] returns
      the addresses of resources referenced by the task_definition attribute. *)
  val get_references : t -> string -> string -> string list option

  (** Get all attribute names that have references for a resource.
      Returns a list of (attribute, references) pairs. *)
  val get_all_references : t -> string -> (string * string list) list

  (** Resolve a reference: given a resource address and an attribute name that
      references another resource, return the referenced resource.
      Returns the first matching resource if multiple are referenced. *)
  val resolve_ref : t -> string -> string -> Resource.t option

  (** Look up a value from a referenced resource.
      [ref_path] is a dot-separated path like "task_definition.values.memory".
      The first component is the attribute name that contains the reference,
      the remaining components are the path within the referenced resource's data.

      Example: [lookup_ref_value refs "aws_ecs_service.svc1" "task_definition.values.memory"]
      would follow the task_definition reference and return the memory value. *)
  val lookup_ref_value : t -> string -> string -> string option

  (** Get all resources in the reference context. *)
  val all_resources : t -> Resource.t list
end
