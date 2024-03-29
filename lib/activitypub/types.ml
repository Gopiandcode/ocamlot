type yojson = Yojson.Safe.t
let pp_yojson fmt vl = Yojson.Safe.pretty_print fmt vl
let equal_yojson l r = Yojson.Safe.equal l r

(** * Collections *)
type 'a ordered_collection_page = {
  id: string;
  prev: string option;
  next: string option;
  is_ordered: bool;
  items: 'a list;
  part_of: string option;
  total_items: int option;
} [@@deriving show, eq]


type 'a ordered_collection = {
  id: string option;
  total_items: int;
  contents: [
    | `Items of (bool * 'a list)
    | `First of 'a ordered_collection_page
  ]
} [@@deriving show, eq]

(** * Events *)
type 'a create = {
  id: string;
  actor: string;
  published: Ptime.t option;
  to_: string list;
  cc: string list;
  direct_message: bool;
  obj: 'a;
  raw: yojson;
} [@@deriving show, eq]


type 'a announce = {
  id: string;
  actor: string;
  published: Ptime.t option;
  to_: string list;
  cc: string list;
  obj: 'a;
  raw: yojson;
} [@@deriving show, eq]


type 'a accept = {
  id: string;
  actor: string;
  published: Ptime.t option;
  obj: 'a;
  raw: yojson;
} [@@deriving show, eq]

type 'a undo = {
  id: string;
  actor: string;
  published: Ptime.t option;
  obj: 'a;
  raw: yojson;
} [@@deriving show, eq]

type 'a delete = {
  id: string;
  actor: string;
  published: Ptime.t option;
  obj: 'a;
  raw: yojson;
}
[@@deriving show, eq]

type 'a event = [
    `Create of 'a create
  | `Announce of 'a announce
  | `Accept of 'a accept
  | `Undo of 'a undo
  | `Delete of 'a delete
] [@@deriving show, eq]


(** * Objects *)
type public_key = {
  id: string;
  owner: string;
  pem: string;
} [@@deriving show, eq]

type person = {
  id: string;
  name: string option;
  url: string option;

  preferred_username: string option;

  inbox: string;
  outbox: string;

  summary: string option;

  public_key: public_key;

  manually_approves_followers: bool;

  discoverable: bool;
  followers: string option;
  following: string option;
  icon: string option;
  raw: yojson;
}  [@@deriving show, eq]

type follow = {
  id: string;
  actor: string;
  cc: string list;
  to_: string list;
  object_: string;
  state: [`Pending | `Cancelled ] option;
  raw: yojson;
} [@@deriving show, eq]

type tag = {
  ty: [`Mention | `Hashtag ];
  href: string;
  name: string;
} [@@deriving show, eq]

type attachment = {
  media_type: string option;
  name: string option;
  type_: string option;
  url: string;
} [@@deriving show, eq]

type note = {
  id: string;
  actor: string;
  attachment: attachment list;
  to_: string list;
  in_reply_to: string option;
  cc: string list;
  content: string;
  sensitive: bool;
  source: string option;
  summary: string option;
  published: Ptime.t option;
  tags: [ `Raw of yojson | `Value of tag ] list;
  raw: yojson;
} [@@deriving show, eq]

type block = {
  id: string;
  obj: string;
  published: Ptime.t option;
  actor: string;
  raw: yojson;
} [@@deriving show, eq]

type like = {
  id: string;
  actor: string;
  published: Ptime.t option;
  obj: string;
  raw: yojson;
}
[@@deriving show, eq]


type core_obj = [
    `Person of person
  | `Follow of follow
  | `Note of note
  | `Block of block
  | `Like of like
  | `Link of string
] [@@deriving show, eq]

type core_event = core_obj event
[@@deriving show, eq]

type obj = [ core_obj | core_event ]
[@@deriving show, eq]

module Webfinger = struct

  type ty = [ `Html | `Json | `ActivityJson | `ActivityJsonLd ]
  [@@deriving show, eq]

  type link =
    | Self of ty * string
    | ProfilePage of ty * string
    | OStatusSubscribe of string
  [@@deriving show, eq]

  type query_result = {
    subject: string;
    aliases: string list;
    links: link list;
  }
  [@@deriving show, eq]

  let self_link query =
    query.links
    |> List.find_map (function
        | Self ((`ActivityJson | `ActivityJsonLd | `Json), url) -> Some (Uri.of_string url)
        | _ -> None)

end

module Nodeinfo = struct

  type software = {
    name: string;
    version: string;
  }
  [@@deriving show, eq]

  type usage_users = {
    total: int;
    active_month: int;
    active_half_year: int;
  }
  [@@deriving show, eq]

  type usage = {
    local_posts: int;
    users: usage_users;
  }
  [@@deriving show, eq]

  type t = {
    software: software;
    protocols: string list;
    inbound_services: string list;
    outbound_services: string list;
    usage: usage;
    open_registrations: bool;
    metadata: yojson option;
    raw: yojson;
  }
  [@@deriving show, eq]

end
