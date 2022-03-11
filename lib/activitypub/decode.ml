open Containers
open Common

let id = D.(one_of ["string", string; "id", field "id" string])

let mention =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected Mention (received %s)" "Mention"
  and* href = field "href" string
  and* name = field "name" string in
  succeed ({ty=`Mention; href;name} : Types.tag)

let hashtag =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected Hashtag (received %s)" "Hashtag"
  and* href = field "href" string
  and* name = field "name" string in
  succeed ({ty=`Hashtag; href;name}: Types.tag)

let tag =
  let open D in
  let* ty = field "type" string in
  match ty with
  | "Mention" -> mention
  | "Hashtag" -> hashtag
  | _ -> fail (Printf.sprintf "unknown tag %s" ty)

let undo obj =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected Undo (received %s)" "Undo"
  and* id = field "id" string
  and* actor = field "actor" id
  and* published = field_opt "published" timestamp
  and* obj = field "object" obj
  and* raw = value in
  succeed ({id;published;actor;obj;raw}: _ Types.undo)

let like =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected Like (received %s)" "Like"
  and* id = field "id" string
  and* actor = field "actor" id
  and* obj = field "object" id
  and* raw = value in
  succeed ({id; actor; obj; raw}: Types.like)


let tombstone =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected Tombstone (received %s)" "Tombstone"
  and* id = field "id" string in
  succeed id

let delete obj =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected Delete (received %s)" "Delete"
  and* id = field "id" string
  and* actor = field "actor" id
  and* published = field_opt "published" timestamp
  and* obj = field "object" obj
  and* raw = value in
  succeed ({id;published;actor;obj;raw}: _ Types.delete)

let block =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected Block (received %s)" "Block"
  and* id = field "id" string
  and* obj = field "object" string
  and* published = field_opt "published" timestamp
  and* actor = field "actor" id
  and* raw = value in
  succeed ({id;published;obj;actor;raw}: _ Types.delete)


let accept obj =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected Accept (received %s)" "Accept"
  and* id = field "id" string
  and* actor = field "actor" id
  and* published = field_opt "published" timestamp
  and* obj = field "object" obj
  and* raw = value in
  succeed ({id;published;actor;obj;raw}: _ Types.delete)

let public_key =
  let open D in
  let* id = field "id" string
  and* owner = field "owner" string
  and* pem = field "publicKeyPem" string in
  succeed ({id;owner;pem}: Types.public_key)

let person =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected Person (received %s)" "Person"
  and* id = field "id" string
  and* name = field_opt "name" string
  and* url = field_or_default "url" (nullable string) None
  and* preferred_username = field_opt "preferredUsername" string
  and* inbox = field "inbox" string
  and* outbox = field "outbox" string
  and* summary = field_opt "summary" string
  and* public_key = field "publicKey" public_key
  and* manually_approves_followers =
    field_or_default "manuallyApprovesFollowers" bool false
  and* discoverable = field_or_default "discoverable" bool false
  and* followers = field_opt "followers" string
  and* following = field_opt "following" string
  and* icon = maybe (at ["icon";"url"] string)
  and* raw = value in
  succeed ({
    id;
    name;
    url;

    preferred_username;

    inbox;
    outbox;

    summary;

    public_key;

    manually_approves_followers;

    discoverable;
    followers;
    following;
    icon;
    raw;
  }: Types.person)

let note = 
  let open D in
  let* () = field "type" @@ constant ~msg:"expected Note (received %s)" "Note"
  and* id = field "id" string
  and* actor = one_of ["actor", field "actor" id; "attributed_to", field "attributedTo" id]
  and* to_ = field "to" (singleton_or_list string)
  and* in_reply_to = field_or_default "inReplyTo" (nullable string) None
  and* cc = field_or_default "cc" (singleton_or_list string) []
  and* content = field "content" string
  and* source = field_opt "source"
                  (one_of ["string", string; "multi-encode", field "content" string])
  and* summary = field_or_default "summary" (nullable string) None
  and* sensitive = field_or_default "sensitive" bool false
  and* published = field_opt "published" timestamp
  and* tags = field_or_default "tag" (lossy_list_of tag) []
  and* raw = value in
  succeed ({ id; actor; in_reply_to; to_; cc; sensitive; content; source; summary; tags; published; raw }: Types.note)

let follow =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected create object (received %s)" "Follow"
  and* actor = field "actor" id
  and* cc = field_or_default "cc" (singleton_or_list string) []
  and* to_ = field "to" (singleton_or_list string)
  and* id = field "id" string
  and* object_ = field "object" string
  and* state = field_opt "state" (string >>= function "pending" -> succeed `Pending
                                                    | "cancelled" -> succeed `Cancelled
                                                    | _ -> fail "unknown status") in
  succeed ({actor; cc; to_; id; object_; state}: Types.follow)

let announce obj =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected create object (received %s)" "Announce"
  and* actor = field "actor" id
  and* id = field "id" string
  and* published = field_opt "published" timestamp
  and* to_ = field "to" (singleton_or_list string)
  and* cc = field_or_default "cc" (singleton_or_list string) []
  and* obj = field "object" obj
  and* raw = value in
  succeed ({id; published; actor; to_; cc; obj; raw}: _ Types.announce)

let create obj =
  let open D in
  let* () = field "type" @@ constant ~msg:"expected create object (received %s)" "Create"
  and* id = field "id" string
  and* actor = field "actor" id
  and* direct_message = field_or_default "direct" bool false
  and* published = field_opt "published" timestamp
  and* to_ = field_or_default "to" (singleton_or_list string) []
  and* cc = field_or_default "cc" (singleton_or_list string) []
  and* obj = field "object" obj
  and* raw = value in

  succeed ({
    id; actor; published;
    to_; cc;
    direct_message;
    obj;
    raw;
  }: _ Types.create)

module Webfinger = struct

  let ty =
    let open D in
    string >>= function
    | str when String.prefix ~pre:Constants.ContentType.html str ->
      succeed `Html
    | str when String.prefix ~pre:Constants.ContentType.plain_json str ->
      succeed `Json
    | str when String.prefix ~pre:Constants.ContentType.activity_json str ->
      succeed `ActivityJson
    | str when String.prefix ~pre:Constants.ContentType.ld_json_activity_streams str ->
      succeed `ActivityJsonLd
    | _ ->
      fail "unsupported self link type"

  let self =
    let open D in
    let* ty = field "type" ty
    and* href = field "href" string in
    succeed @@ Types.Webfinger.Self (ty, href)

  let profile_page =
    let open D in
    let* ty = field "type" ty
    and* href = field "href" string in
    succeed @@ Types.Webfinger.ProfilePage (ty, href)

  let ostatus_subscribe =
    let open D in
    let* template = field "template" string in
    succeed @@ Types.Webfinger.OStatusSubscribe template

  let link =
    let open D in
    let* rel = field "rel" string in
    match rel with
    | "self" -> self
    | str when String.equal str Constants.Webfinger.ostatus_rel ->
      ostatus_subscribe
    | str when String.equal str Constants.Webfinger.profile_page ->
      profile_page
    | _ -> failwith "unsupported link relation"

  let query_result =
    let open D in
    let* subject = field "subject" string
    and* aliases = field "aliases" (list string)
    and* links = field "links" (list_ignoring_unknown link) in

    succeed Types.Webfinger.{subject;aliases;links}

end