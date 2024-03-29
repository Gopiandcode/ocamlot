open Petrol
open Petrol.Postgres

let version_0_0_1 = VersionedSchema.version [0;0;1]
let version_0_0_2 = VersionedSchema.version [0;0;2]
let version_0_0_3 = VersionedSchema.version [0;0;3]
let version_0_0_4 = VersionedSchema.version [0;0;4]
let version_0_0_5 = VersionedSchema.version [0;0;5]
let version_0_0_6 = VersionedSchema.version [0;0;6]
let version_0_0_7 = VersionedSchema.version [0;0;7]
let version_0_0_8 = VersionedSchema.version [0;0;8]


let db = VersionedSchema.init version_0_0_8 ~name:"ocamlot"

module DreamSession = struct

  (* declare the dream table here to ensure that dream doesn't complain *)
  let table, Expr.[id;label;expires_at;payload] =
    VersionedSchema.declare_table db ~name:"dream_session"
      Schema.[
        field ~constraints:[primary_key ()] "id" ~ty:Type.text;
        field ~constraints:[not_null ()] "label" ~ty:Type.text;
        field ~constraints:[not_null ()] "expires_at" ~ty:Type.real;
        field ~constraints:[not_null ()] "payload" ~ty:Type.text
      ]

end


module UserImage = struct

  let table, Expr.[path; hash] =
    VersionedSchema.declare_table db ~name:"user_images"
      Schema.[
        field ~constraints:[primary_key (); not_null (); unique ()] "path" ~ty:Type.text;
        field ~constraints:[not_null (); unique ()] "hash" ~ty:Type.bytea;
      ] ~since:version_0_0_2

end


module Admin = struct

  let table, Expr.[key; value] =
    VersionedSchema.declare_table db ~name:"admin"
      Schema.[
        field ~constraints:[primary_key (); not_null (); unique ()] "admin_key" ~ty:Type.text;
        field ~constraints:[not_null ()] "admin_value" ~ty:Type.text;
      ] ~since:version_0_0_6

end


module Activity = struct

  let table, Expr.[id; raw_data] =
    VersionedSchema.declare_table db ~name:"activity"
      Schema.[
        field ~constraints:[primary_key ()] "activity_id" ~ty:Type.text;                     (* uuid of the data *)
        field ~constraints:[not_null ()] "activity_raw_data" ~ty:Type.text;                  (* json data (Yojson.t) *)
      ]

end

module LocalUser = struct

  let table, (Expr.[id; username; password; display_name; about; profile_picture; manually_accept_follows; is_admin; pubkey; privkey] as all_fields) =
    VersionedSchema.declare_table db ~name:"local_user"
      Schema.[
        field ~constraints:[primary_key ()] "local_user_id" ~ty:Type.big_serial;              (* internal id, not exposed *)
        field ~constraints:[unique (); not_null ()] "local_user_username" ~ty:Type.text;       (* username *)
        field ~constraints:[not_null ()] "local_user_password" ~ty:Type.text;                  (* password hash + salt *)
        field "local_user_display_name" ~ty:Type.text;                                         (* display name - if null then username *)
        field "local_user_about" ~ty:Type.text;                                                (* about text for the user *)
        field ~constraints:[
          foreign_key ~table:UserImage.table ~columns:Expr.[UserImage.path]
             ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
        ] "local_user_profile_picture" ~ty:Type.text;                                          (* profile picture of the user *)
        field ~constraints:[not_null ()] "local_user_manually_accept_follows" ~ty:Type.bool;   (* whether the user manually accepts follows *)
        field ~constraints:[not_null ()] "local_user_is_admin" ~ty:Type.bool;                  (* whether the user is an admin *)
        field ~constraints:[not_null ()] "local_user_pubkey" ~ty:Type.text;                    (* public key for the user (X509.Public_key.t) *)
        field ~constraints:[not_null ()] "local_user_privkey" ~ty:Type.text;                   (* private key for the user (X509.Private_key.t) *)
      ]
      ~migrations:[version_0_0_2, [
        Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit) {sql| ALTER TABLE local_user ADD COLUMN local_user_profile_picture TEXT REFERENCES user_images (path) ON DELETE RESTRICT ON UPDATE RESTRICT |sql}
      ]]

end

module RemoteInstance = struct

  let table, Expr.[id;url;last_unreachable] =
    VersionedSchema.declare_table db ~name:"remote_instance"
      Schema.[
        field ~constraints:[primary_key ()] "remote_instance_id" ~ty:Type.big_serial;
        field ~constraints:[unique ()] "remote_instance_url" ~ty:Type.text;
        field "remote_instance_last_unreachable" ~ty:Type.text;
      ]

end

module RemoteUser = struct

  let table, Expr.[
    id;
    username;
    instance_id;
    display_name;
    url;
    inbox;
    outbox;
    followers;
    following;
    summary;
    public_key_pem;
    profile_picture;
  ] = VersionedSchema.declare_table db ~name:"remote_user"
        Schema.[
          field ~constraints:[primary_key ()] "remote_user_id" ~ty:Type.big_serial;       (* internal id of the user *)
          field ~constraints:[not_null ()] "remote_user_username" ~ty:Type.text;          (* username *)

          field ~constraints:[
            foreign_key ~table:RemoteInstance.table
              ~columns:Expr.[RemoteInstance.id]
              ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
          ] "remote_user_instance_id" ~ty:Type.big_serial;                               (* reference to the instance where the user lives  *)
          field "remote_user_display_name" ~ty:Type.text;                                (* display name of the user, if null then username *)
          field ~constraints:[unique (); not_null ()] "remote_user_url" ~ty:Type.text;   (* url of actor (obtained by webfinger if needed) *)
          field "remote_user_inbox" ~ty:Type.text;                                       (* inbox url of the user *)
          field "remote_user_outbox" ~ty:Type.text;                                      (* outbox url of the user *)
          field "remote_user_followers" ~ty:Type.text;                                   (* followers url of the user *)
          field "remote_user_following" ~ty:Type.text;                                   (* following url of the user *)
          field "remote_user_summary" ~ty:Type.text;                                     (* profile string of the user *)

          field ~constraints:[not_null ()]
            "remote_user_public_key_pem" ~ty:Type.text;                                  (* public key of the user *)
          field
            "remote_user_profile_picture"
            ~ty:Type.text;                                                   (* profile picture of the user *)

        ]
        ~migrations:[version_0_0_3, [
            Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit) {sql| ALTER TABLE remote_user ADD COLUMN remote_user_profile_picture TEXT |sql}
          ]]

end

module Actor = struct

  let table, Expr.[id; local_id; remote_id] =
    VersionedSchema.declare_table db ~name:"actor"
      Schema.[
        field ~constraints:[primary_key ()]  "actor_id" ~ty:Type.big_serial;      (* internal id for referring to actors *)
        field ~constraints:[
          unique ();
          foreign_key ~table:LocalUser.table ~columns:Expr.[LocalUser.id]
            ~on_update:`RESTRICT
            ~on_delete:`RESTRICT ()                                         (* local id if a local user *)
        ] "actor_local_id" ~ty:Type.big_int;
        field ~constraints:[
          unique ();
          foreign_key ~table:RemoteUser.table ~columns:Expr.[RemoteUser.id]
            ~on_update:`RESTRICT
            ~on_delete:`RESTRICT ()                                         (* remote id if a remote user *)
        ] "actor_remote_id" ~ty:Type.big_int;
      ]

end

module Tag = struct

  let table, Expr.[id; name] =
    VersionedSchema.declare_table db ~name:"tags"
      Schema.[
        field ~constraints:[primary_key ()] "tag_id" ~ty:Type.big_serial;       (* tag id *)
        field ~constraints:[not_null (); unique ()] "tag_name" ~ty:Type.text;   (* tag name  *)
      ]

end

module Posts = struct

  let table, Expr.[
    id;
    public_id;
    url;
    author_id;

    is_public;
    is_follower_public;

    summary;
    content_type;
    post_source;

    published;
    raw_data;

    deleted;
    in_reply_to;
  ] =
    VersionedSchema.declare_table db ~name:"posts"
      Schema.[
        field ~constraints:[primary_key ()] "posts_id" ~ty:Type.big_serial;          (* internal post id, not exposed *)
        field ~constraints:[unique ()] "posts_public_id" ~ty:Type.text;                                       (* if post by local user, assign public id *)
        field ~constraints:[not_null (); unique ()] "posts_url" ~ty:Type.text;       (* url/id of post, if local then /api/posts/<public_id> *)
        field ~constraints:[
          not_null ();
          foreign_key ~table:Actor.table ~columns:Expr.[Actor.id]
            ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
        ] "posts_author_id" ~ty:Type.big_serial;                                     (* author of the post *)

        field ~constraints:[not_null ()] "posts_is_public" ~ty:Type.bool;            (* is the post public? or only to the mentioned users *)
        field ~constraints:[not_null ()] "posts_is_follower_public" ~ty:Type.bool;   (* is the post sent to followers mentioned users *)

        field "posts_summary" ~ty:Type.text;                                         (* subject of the post *)
        field ~constraints:[not_null ()] "posts_content_type" ~ty:Type.int;         (* type of the content *)
        field ~constraints:[not_null ()] "posts_post_source" ~ty:Type.text;          (* source of the content *)

        field ~constraints:[not_null ()] "posts_published" ~ty:Type.text;            (* date at which post was published (Ptime) *)

        field "posts_raw_data" ~ty:Type.text;                                        (* if by an external user, then keep json of the post (Yojson.Safe.t) *)
        field "posts_deleted" ~ty:Type.bool;

        field "posts_in_reply_to" ~ty:Type.text;
      ]
      ~migrations:[
        version_0_0_5, [
          Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit) {sql| ALTER TABLE posts ADD COLUMN posts_deleted INTEGER |sql}
        ];
        version_0_0_7, [
          Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit) {sql| ALTER TABLE posts ADD COLUMN posts_in_reply_to TEXT |sql}
        ];
      ]

  module PostTo = struct
    let table, Expr.[post_id; actor_id] =
      VersionedSchema.declare_table db ~name:"post_to"
        Schema.[
          field ~constraints:[
            not_null ();
            foreign_key ~table ~columns:Expr.[id]
              ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
          ] "post_to_post_id" ~ty:Type.big_serial;
          field ~constraints:[
            not_null ();
            foreign_key ~table:Actor.table ~columns:Expr.[Actor.id]
              ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
          ] "post_to_actor_id" ~ty:Type.big_serial
        ] ~constraints:Schema.[
          table_unique ["post_to_post_id"; "post_to_actor_id"]
        ]
  end

  module PostCc = struct
    let table, Expr.[post_id; actor_id] =
      VersionedSchema.declare_table db ~name:"post_cc"
        Schema.[
          field ~constraints:[
            not_null ();
            foreign_key ~table ~columns:Expr.[id]
              ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
          ] "post_cc_post_id" ~ty:Type.big_serial;
          field ~constraints:[
            not_null ();
            foreign_key ~table:Actor.table ~columns:Expr.[Actor.id]
              ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
          ] "post_cc_actor_id" ~ty:Type.big_serial
        ] ~constraints:Schema.[
          table_unique ["post_cc_post_id"; "post_cc_actor_id"]
        ]
  end

  module PostMentions = struct
    let table, Expr.[post_id; actor_id] =
      VersionedSchema.declare_table db ~name:"post_mention"
        Schema.[
          field ~constraints:[
            not_null ();
            foreign_key ~table ~columns:Expr.[id]
              ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
          ] "post_mention_post_id" ~ty:Type.big_serial;
          field ~constraints:[
            not_null ();
            foreign_key ~table:Actor.table ~columns:Expr.[Actor.id]
              ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
          ] "post_mention_actor_id" ~ty:Type.big_serial
        ]    
        ~constraints:Schema.[
          table_unique ["post_mention_post_id"; "post_mention_actor_id"]
        ]
  end

  module PostTags = struct
    let table, Expr.[post_id; tag_id; url] =
      VersionedSchema.declare_table db ~name:"post_tags"
        Schema.[
          field ~constraints:[
            not_null ();
            foreign_key ~table ~columns:Expr.[id]
              ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
          ] "post_tags_post_id" ~ty:Type.big_serial;                                   (* post id *)
          field ~constraints:[
            not_null ();
            foreign_key ~table:Tag.table ~columns:Expr.[Tag.id]
              ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
          ] "post_tags_tag_id" ~ty:Type.big_serial;                                    (* tag id *)
          field "post_tags_url" ~ty:Type.text;                                         (* href of the tag root (head to url to see all posts) if ext. *)
        ] ~constraints:Schema.[table_primary_key ["post_tags_post_id"; "post_tags_tag_id"]]
  end

  module PostContext = struct

    let table, Expr.[parent; child] =
      VersionedSchema.declare_table db ~name:"post_context"
        Schema.[
          field ~constraints:[foreign_key ~table:table ~columns:Expr.[id] ()] "post_context_parent" ~ty:Type.big_serial;
          field ~constraints:[foreign_key ~table:table ~columns:Expr.[id] ()] "post_context_child" ~ty:Type.big_serial;
        ] ~since:version_0_0_7
        ~constraints:Schema.[
          table_unique ["post_context_parent"; "post_context_child"]
        ]

  end

  module PostAttachments = struct

    let table, Expr.[post_id; media_type; url] =
      VersionedSchema.declare_table db ~name:"post_attachments"
        Schema.[
          field ~constraints:[foreign_key ~table:table ~columns:Expr.[id] ()] "post_attachment_post_id" ~ty:Type.big_serial;
          field "post_attachment_media_type" ~ty:Type.text;
          field ~constraints:[not_null ()] "post_attachment_url" ~ty:Type.text;
        ] ~since:version_0_0_8

  end

end


module Likes = struct

  let table, Expr.[
    id;
    public_id;
    url;
    raw_data;
    published;
    post_id;
    actor_id
  ] =
    VersionedSchema.declare_table db ~name:"likes"
      Schema.[
        field ~constraints:[primary_key ()] "likes_id" ~ty:Type.big_serial;
        field "likes_public_id" ~ty:Type.text;
        field ~constraints:[not_null ()] "likes_url" ~ty:Type.text;
        field "likes_raw_data" ~ty:Type.text;
        field ~constraints:[not_null ()] "likes_published" ~ty:Type.text;
        field ~constraints:[
          not_null ();
          foreign_key ~table:Posts.table ~columns:Expr.[Posts.id]
            ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
        ] "likes_post_id" ~ty:Type.big_serial;
        field ~constraints:[
          not_null ();
          foreign_key ~table:Actor.table ~columns:Expr.[Actor.id]
            ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
        ] "likes_actor_id" ~ty:Type.big_serial;
      ]

end


module Reboosts = struct

  let table, Expr.[
    id;
    public_id;
    url;
    raw_data;
    published;
    post_id;
    actor_id
  ] =
    VersionedSchema.declare_table db ~name:"reboosts"
      Schema.[
        field ~constraints:[primary_key ()] "reboost_id" ~ty:Type.big_serial;
        field "reboost_public_id" ~ty:Type.text;
        field ~constraints:[not_null ()] "reboost_url" ~ty:Type.text;
        field "reboost_raw_data" ~ty:Type.text;
        field ~constraints:[not_null ()] "reboost_published" ~ty:Type.text;
        field ~constraints:[
          not_null ();
          foreign_key ~table:Posts.table ~columns:Expr.[Posts.id]
            ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
        ] "reboost_post_id" ~ty:Type.big_serial;
        field ~constraints:[
          not_null ();
          foreign_key ~table:Actor.table ~columns:Expr.[Actor.id]
            ~on_update:`RESTRICT ~on_delete:`RESTRICT ()
        ] "reboost_actor_id" ~ty:Type.big_serial;
      ] ~since:version_0_0_4

end


module Follows = struct

  let table, Expr.[
    id;
    public_id;
    url;
    raw_data;
    pending;
    created;
    updated;
    author_id;
    target_id
  ] =
    VersionedSchema.declare_table db ~name:"follows"
      Schema.[
        field ~constraints:[primary_key ()] "follows_id" ~ty:Type.big_serial;
        field "follows_public_id" ~ty:Type.text;
        field ~constraints:[not_null ()] "follows_url" ~ty:Type.text;
        field "follows_raw_data" ~ty:Type.text;
        field ~constraints:[not_null ()] "follows_pending" ~ty:Type.bool;

        field ~constraints:[not_null ()] "follows_created" ~ty:Type.text;
        field "follows_updated" ~ty:Type.text;

        field ~constraints:[
          not_null ();
          foreign_key ~table:Actor.table ~columns:Expr.[Actor.id] ()
        ] "follows_author_id" ~ty:Type.big_serial;
        field ~constraints:[
          not_null ();
          foreign_key ~table:Actor.table ~columns:Expr.[Actor.id] ()
        ] "follows_target_id" ~ty:Type.big_serial;
      ]

end

