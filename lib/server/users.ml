[@@@warning "-33"]
open Containers
open Common

module StringSet = Set.Make(String)

let log = Logging.add_logger "web.user"
module H = Tyxml.Html
(* * Utils  *)

let get_user_checked req username =
  let* current_user = current_user req in
  match current_user with
  | None ->
    return_ok None
  | Some current_user when not (String.equal username current_user.Database.LocalUser.username) ->
    return (Error (`Unauthorised ("Don't have permission to edit " ^ username ^ "'s profile")))
  | Some current_user ->
    return_ok (Some current_user)

let extract_single_multipart_data = function
  | [(None, data)] -> Ok data
  | _ -> Error (`InvalidData "expected a single text input")

let extract_file_multipart_data = function
  | [(Some fname, data)] -> Ok (fname, data)
  | _ -> Error (`InvalidData "expected a file input")

(* * Actor *)
(* ** Edit (html) *)

let handle_actor_edit_get req =
  let username = Dream.param req "username" in
  let* current_user = get_user_checked req username in
  match current_user with
  | None ->
    redirect req "/feed"
  | Some current_user ->
    let token = Dream.csrf_token req in
    let* user = Extract.extract_user_profile req current_user in
    let* headers, action = Navigation.build_navigation_bar req in
    tyxml @@
    View.Page.render_page (username ^ "'s Profile") [
      View.Header.render_header ?action headers;
      View.Components.render_heading
        ~icon:"E" ~current:"Edit Profile"
        ~actions:View.Utils.[{
          url="save"; text="Save";form=Some "edit-user"
        }] ();

      View.Profile.render_update_profile_box
        ~id:"edit-user" ~action:("/users/" ^ username ^ "/edit")
        ~fields:["dream.csrf", token] user;
    ]

(* ** Edit (html) post  *)
let handle_actor_edit_post req =
  log.debug (fun f -> f "POST to actor edit");
  let username = Dream.param req "username" in
  let* current_user = get_user_checked req username in
  match current_user with
  | None ->
    redirect req "/feed"
  | Some current_user ->
    let username = Dream.param req "username" in
    let* data = (Dream.multipart req)
                |> sanitize_form_error ([%show: (string * (string option * string) list) list]) in
    match data with
    | _ when List.Assoc.mem ~eq:String.equal "avatar" data &&
             not @@ List.is_empty (List.Assoc.get_exn ~eq:String.equal "avatar" data) ->
      let* avatar =
        List.Assoc.get ~eq:String.equal "avatar" data
        |> VResult.lift_result_check extract_file_multipart_data
        |> VResult.flat_map
             (VResult.lift_result_check
                (VResult.lift_pair_snd
                   (VResult.check_input_size "avatar" 3_000_000)))
        |> Lwt_result.lift in
      begin
        match avatar with
        | None -> redirect req "/feed"
        | Some (fname, avatar) ->
          log.debug (fun f -> f "got file %s, [%d]{%s..}" fname
                                (String.length avatar) (String.take 100 avatar));
          let* image = Images.upload_file req ~fname ~data:avatar in
          let* () =
            sql req
              (Database.LocalUser.update_profile_picture
                 ~id:current_user.Database.LocalUser.id
                 ~image) in
          redirect req (Configuration.Url.user_path username)
      end

    | _ when List.Assoc.mem ~eq:String.equal "display-name" data ||
             List.Assoc.mem ~eq:String.equal "about" data ->
      let* display_name =
        List.Assoc.get ~eq:String.equal "display-name" data
        |> VResult.lift_result_check extract_single_multipart_data
        |> Result.flat_map
             (VResult.lift_result_check (VResult.check_input_size "display-name" 80))
        |> Result.map (Option.filter (Fun.negate String.is_empty))
        |> Lwt_result.lift in
      let* about =
        List.Assoc.get ~eq:String.equal "about" data
        |> VResult.lift_result_check extract_single_multipart_data
        |> Result.flat_map
             (VResult.lift_result_check (VResult.check_input_size "about" 2048))
        |> Result.map (Option.filter (Fun.negate String.is_empty))
        |> Lwt_result.lift in
      let* () =
        match display_name with
        | None -> return_ok ()
        | Some display_name ->
          sql req
            (Database.LocalUser.update_display_name
               ~id:current_user.Database.LocalUser.id
               ~display_name) in
      let* () =
        match about with
        | None -> return_ok ()
        | Some about ->
          sql req
            (Database.LocalUser.update_about
               ~id:current_user.Database.LocalUser.id
               ~about) in
      redirect req (Configuration.Url.user_path username)
    | _ ->
      redirect req (Configuration.Url.user_path username)


(* ** Get (html) *)
let handle_actor_get_html req =
  let username = Dream.param req "username" in
  let* user =
    Dream.sql req
      (Database.LocalUser.find_user ~username)
    |> map_err (fun err -> `DatabaseError (Caqti_error.show err))
    >>= (fun v -> return (lift_opt ~else_:(fun () -> `UserNotFound username) v)) in
  (* let> _current_user = Common.with_current_user req in *)
  (* let* no_following, no_followers, _no_posts =
   *   Dream.sql req (fun db ->
   *     let* user = Database.Actor.create_local_user ~local_id:(user.Database.LocalUser.id) db in
   *     let* following = Database.Follows.count_following ~author:user db in
   *     let* followers = Database.Follows.count_followers ~target:user db in
   *     let* posts = Database.Posts.count_posts_by_author ~author:user db in
   *     Lwt.return_ok (following, followers,posts)
   *   ) |> map_err (fun err -> `DatabaseError (Caqti_error.show err)) in *)
  let timestamp = Dream.query req "start"
                  |> Fun.flip Option.bind (fun v -> Ptime.of_rfc3339 v |> Result.to_opt)
                  |> Option.map (fun (t, _, _) -> t)
                  |> Option.value ~default:(Ptime_clock.now ()) in
  let offset = Dream.query req "offset"
               |> Fun.flip Option.bind Int.of_string
               |> Option.value ~default:0 in
  let* profile = Extract.extract_user_profile req user in

  let* contents =
    sql req begin fun db ->
      let* user = Database.Actor.create_local_user ~local_id:(user.Database.LocalUser.id) db in
      match Dream.query req "state" with
      | Some "followers" ->
        let* follows = 
          Database.Follows.collect_followers_for_actor
            ~since:timestamp ~offset:(offset * 10) ~limit:10 ~id:user db in
        let* follows =
          Lwt_list.map_s (fun follow ->
            let target = follow.Database.Follows.target_id in
            let* target = Database.Actor.resolve ~id:target db in
            Lwt.return_ok (follow, target)) follows
          >> Result.flatten_l in
        Lwt.return_ok (`Followers (timestamp, offset, follows))
      | Some "following" ->
        let* follows = 
          Database.Follows.collect_following_for_actor
            ~offset:(offset * 10) ~limit:10 ~since:timestamp ~id:user db in
        let* follows =
          Lwt_list.map_s (fun follow ->
            let target = follow.Database.Follows.target_id in
            let* target = Database.Actor.resolve ~id:target db in
            Lwt.return_ok (follow, target)) follows
          |> lift_pure in
        let* follows = Lwt.return @@ Result.flatten_l follows in
        Lwt.return_ok (`Following (timestamp, offset, follows))
      | Some "post" | _ ->
        let* posts =
          Database.Posts.collect_posts_by_author
            ~offset:(offset * 10) ~start_time:timestamp ~limit:10 ~author:user db in
        Lwt.return_ok (`Posts (timestamp, offset, posts))
    end in
  let heading =
    let options =
      View.Utils.[
        {url=Format.sprintf "/users/%s?state=posts" username; text="Posts"; form=None};
        {url=Format.sprintf "/users/%s?state=followers" username; text="Followers"; form=None};
        {url=Format.sprintf "/users/%s?state=following" username; text="Following"; form=None};
      ] in
    match contents with
    | `Posts _ ->
      View.Components.render_heading ~icon:"1" ~current:"Posts" ~options ()
    | `Followers _ ->
      View.Components.render_heading ~icon:"2" ~current:"Followers" ~options ()
    | `Following _ ->
      View.Components.render_heading ~icon:"3" ~current:"Following" ~options () in
  let* contents =
    match contents with
    | `Posts (_, _, posts) ->
      let+ posts = Lwt_list.map_s (fun post ->
        Extract.extract_post req post
      ) posts >> Result.flatten_l in
      View.Post_grid.render_post_grid posts
    | `Followers (_, _, users) ->
      let+ users = Lwt_list.map_s (fun (freq, user) ->
        let* user = Extract.extract_user req user in
        let* socials = Extract.extract_user_socials req freq.Database.Follows.author_id in
        return_ok (user,socials)
      ) users >> Result.flatten_l in
      View.User.render_users_grid users
    | `Following (_, _, users) ->
      let+ users = Lwt_list.map_s (fun (freq, user) ->
        let* user = Extract.extract_user req user in
        let* socials = Extract.extract_user_socials req freq.Database.Follows.target_id in
        return_ok (user,socials)
      ) users >> Result.flatten_l in
      View.User.render_users_grid users in
  let* headers, action = Navigation.build_navigation_bar req in
  tyxml @@
  View.Page.render_page (username ^ "'s Profile") [
    View.Header.render_header ?action headers;
    View.Profile.render_profile profile;
    heading;
    contents;
  ]


(* ** Get (json) *)
let handle_actor_get_json req =
  let username = Dream.param req "username" in
  let* user =
    Dream.sql req
      (Database.LocalUser.find_user ~username)
    |> map_err (fun err -> `DatabaseError (Caqti_error.show err))
    >>= (fun v -> return (lift_opt ~else_:(fun () -> `UserNotFound username) v)) in
  let user_json = (user
                   |> Database.Interface.LocalUser.convert_to
                   |> Activitypub.Encode.person) in
  log.debug (fun f -> f "query for %s --> %a" username Yojson.Safe.pp user_json);
  activity_json user_json

(* ** Get *)
let handle_actor_get req =
  let content_type = Dream.header req "Accept"
                     |> Option.value ~default:(Activitypub.Constants.ContentType.html) in
  log.debug (fun f -> f "got user request for %s" content_type);
  match Activitypub.Constants.ContentType.of_string content_type with
  | None ->
    log.debug (fun f -> f "no idea for %s, returning html" content_type);
    Error_handling.handle_error_html
      (fun _ -> return @@ Error (`UnsupportedContentType content_type)) req
  | Some `HTML ->
    log.debug (fun f -> f "%s -> html; returning html" content_type);
    Error_handling.handle_error_html
      (handle_actor_get_html )req
  | Some `JSON ->
    log.debug (fun f -> f "%s -> json; returning json" content_type);
    Error_handling.handle_error_json
      (handle_actor_get_json) req

(* * Outbox *)
(* ** Get  *)
let handle_outbox_get req =
  Dream.log "GET %s/outbox" (Dream.param req "username");
  Dream.respond ~status:`OK ""

(* ** Post *)
(* let handle_outbox_post req =
 *   Dream.log "POST %s/outbox" (Dream.param req "username");
 *   let* body = Dream.body req in
 *   Dream.log "DATA: %s" body;
 *   Dream.respond ~status:`OK "" *)

(* * Followers *)
(* ** Get *)
let handle_followers_get req =
  let username = Dream.param req "username" in
  let* user = Dream.sql req (Database.LocalUser.find_user ~username)
              |> map_err (fun err -> `DatabaseError (Caqti_error.show err)) in
  let* user = return @@ lift_opt ~else_:(fun _ -> `UserNotFound username)
                          user in
  let offset =
    let open Option in
    let* page = Dream.query req "page"
    and* start_time = Dream.query req "start" in
    let* page = Int.of_string page 
    and* start_time, _, _ = Ptime.of_rfc3339 start_time
                            |> Result.to_opt in
    return (page, start_time) in
  let is_page = Option.is_some offset in
  let offset, start_time = Option.value ~default:(0, Ptime_clock.now ())
                             offset in
  let* followers_collection_page =
    Dream.sql req
      (Ap_resolver.build_followers_collection_page
         start_time offset user) in
  let data =
    if is_page
    then Activitypub.Encode.ordered_collection_page (Decoders_yojson.Safe.Encode.string)
           followers_collection_page
    else Activitypub.Encode.ordered_collection (Decoders_yojson.Safe.Encode.string)
           ({
             id = Some (
               Configuration.Url.user_followers (user.Database.LocalUser.username)
               |> Uri.to_string
             );
             total_items=followers_collection_page.total_items
                         |> Option.get_exn_or "invalid assumption";
             contents=`First followers_collection_page; 
           } : string Activitypub.Types.ordered_collection) in
  activity_json data

(* * Following *)
(* ** Get *)
let handle_following_get req =
  let username = Dream.param req "username" in
  let* user = Dream.sql req (Database.LocalUser.find_user ~username)
              |> map_err (fun err -> `DatabaseError (Caqti_error.show err)) in
  let* user = return @@ lift_opt ~else_:(fun _ -> `UserNotFound username)
                          user in
  let offset =
    let open Option in
    let* page = Dream.query req "page"
    and* start_time = Dream.query req "start" in
    let* page = Int.of_string page 
    and* start_time, _, _ = Ptime.of_rfc3339 start_time
                            |> Result.to_opt in
    return (page, start_time) in
  let is_page = Option.is_some offset in
  let offset, start_time = Option.value ~default:(0, Ptime_clock.now ())
                             offset in
  let* following_collection_page =
    Dream.sql req
      (Ap_resolver.build_following_collection_page
         start_time offset user) in
  let data =
    if is_page
    then Activitypub.Encode.ordered_collection_page (Decoders_yojson.Safe.Encode.string)
           following_collection_page
    else Activitypub.Encode.ordered_collection (Decoders_yojson.Safe.Encode.string)
           ({
             id = Some (
               Configuration.Url.user_following (user.Database.LocalUser.username)
               |> Uri.to_string
             );
             total_items=following_collection_page.total_items
                         |> Option.get_exn_or "invalid assumption";
             contents=`First following_collection_page; 
           } : string Activitypub.Types.ordered_collection) in
  activity_json data

(* * Users *)
(* ** Utils *)
let parse_user_types = function
  | "local" -> Some `Local
  | "remote" -> Some `Remote
  | _ -> None

let encode_user_types = function
  | `Local -> "local"
  | `Remote -> "remote"

let show_user_types = function
  | `Local -> "Local Users"
  | `Remote -> "Remote Users"


let classify_query s =
  let s = String.trim s in
  let has_spaces = String.contains s ' ' in
  let contains_at = (String.contains s '@') in
  if has_spaces || not contains_at
  then `SearchLike (String.split_on_char ' ' s)
  else begin
    let domain = String.split_on_char '@' s in
    match domain with
    | [username; domain] -> `Resolve (username, domain)
    | username :: _ -> `SearchLike [username]
    | _ -> `SearchLike [s]
  end

let render_users_page ?ty ?search_query req user_type users =
  let* headers, action = Navigation.build_navigation_bar req in
  tyxml (View.Page.render_page (show_user_types user_type) [
    View.Header.render_header ?action headers;
    View.Components.render_heading
      ~icon:(match user_type with `Local -> "1" | _ -> "2")
      ~current:(show_user_types user_type) ~options:[
        {text="Local Users"; url="/users?type=" ^ encode_user_types `Local; form=None};
        {text="Remote Users"; url="/users?type=" ^ encode_user_types `Remote; form=None}
      ] ();
    View.User.render_users_search_box
      ?fields:(Option.map (fun ty -> ["type", encode_user_types ty]) ty)
      ?initial_value:search_query ();
    View.User.render_users_grid users;
  ])

(* ** Local users (get) *)
let handle_local_users_get req =
  let offset_start =
    Dream.query req "offset-start"
    |> Option.flat_map Int.of_string
    |> Option.value ~default:0 in
  let limit = 10 in
  let search_query = Dream.query req "search" in

  let* users =
    match search_query with
    | Some query when not (String.is_empty query) ->
      let query = "%" ^ (String.replace ~sub:" " ~by:"%" query) ^ "%" in
      log.debug (fun f -> f "local users search is %s" query);
      Dream.sql req (fun db ->
        Database.LocalUser.find_local_users
          ~offset:(offset_start * limit) ~limit
          ~pattern:query db)
      |> map_err (fun err -> `DatabaseError (Caqti_error.show err))
    | _ ->
      Dream.sql req (fun db ->
        Database.LocalUser.collect_local_users
          ~offset:(offset_start * limit)
          ~limit:limit db)
      |> map_err (fun err -> `DatabaseError (Caqti_error.show err)) in
  let* users_w_stats =
    Lwt_list.map_s (fun user ->
      let* user_link = sql req (Database.Actor.create_local_user ~local_id:(user.Database.LocalUser.id)) in
      let* user = Extract.extract_user req (`Local user.Database.LocalUser.id) in
      let* socials = Extract.extract_user_socials req user_link in
      return_ok (user, socials)
    ) users
    >> Result.flatten_l in
  render_users_page ~ty:`Local ?search_query req `Local users_w_stats

(* ** Remote users (get) *)
let handle_remote_users_get req =
  let* current_user_link = current_user_link req in
  let offset =
    Dream.query req "offset-start"
    |> Option.flat_map Int.of_string
    |> Option.value ~default:0 in
  let limit = 10 in
  let search_query = Dream.query req "search" in
  let* users =
    match search_query, current_user_link with
    | None, _ | Some _, None ->
      Dream.sql req (fun db ->
        Database.RemoteUser.collect_remote_users
          ~limit ~offset:(offset * limit) db)
      |> map_err (fun err -> `DatabaseError (Caqti_error.show err))
    | Some query, Some _ ->
      match classify_query query with
      | `Resolve (user, domain) ->
        log.debug (fun f -> f "received explicit search - sending task to worker");
        Worker.send_task Worker.(SearchRemoteUser {
          username=user; domain=Some domain
        });
        let query = "%" ^ user ^ "%" in
        Dream.sql req (fun db ->
          Database.RemoteUser.find_remote_users ~limit
            ~offset:(offset * limit) ~pattern:query db
        )
        |> map_err (fun err -> `DatabaseError (Caqti_error.show err))
      | `SearchLike query ->
        log.debug (fun f -> f "received implicit search");
        begin match query with
        | [username] -> 
          log.debug (fun f -> f "implicit search over single parameter - sending task to worker");
          Worker.send_task Worker.(SearchRemoteUser {
            username; domain=None
          });
        | _ -> ()
        end;
        let query = "%" ^ (String.concat "%" query) ^ "%" in
        Dream.sql req (fun db ->
          Database.RemoteUser.find_remote_users ~limit
            ~offset:(offset * limit) ~pattern:query db
        )
        |> map_err (fun err -> `DatabaseError (Caqti_error.show err)) in
  let* users_w_stats =
    Lwt_list.map_p (fun (_url, user) ->
      let* user_link = sql req (Database.Actor.create_remote_user ~remote_id:(user.Database.RemoteUser.id)) in
      let* user = Extract.extract_user req (`Remote user.Database.RemoteUser.id) in
      let* socials = Extract.extract_user_socials req user_link in
      return_ok (user, socials)
    ) users
    >> Result.flatten_l in
  render_users_page ~ty:`Remote ?search_query req `Remote users_w_stats

(* ** Users (get) *)
let handle_users_get req =
  let user_list_ty =
    Dream.query req "type"
    |> Option.flat_map parse_user_types
    |> Option.value ~default:`Local in
  match user_list_ty with
  | `Local ->
    handle_local_users_get req
  | `Remote ->
    handle_remote_users_get req

(* * Follow local *)
let handle_follow_local_user current_user username req =
  let* current_user =
    Dream.sql req (Database.Actor.create_local_user ~local_id:(current_user.Database.LocalUser.id))
    |> map_err (fun err -> `DatabaseError (Caqti_error.show err)) in
  let* target_user =
    Dream.sql req
      (Database.LocalUser.find_user ~username)
    |> map_err (fun err -> `DatabaseError (Caqti_error.show err))
    >>= (fun v -> return (lift_opt ~else_:(fun () -> `UserNotFound username) v)) in
  let* target_user =
    Dream.sql req @@ Database.Actor.create_local_user ~local_id:(target_user.Database.LocalUser.id)
    |> map_err (fun err -> `DatabaseError (Caqti_error.show err)) in
  let* is_following =
    Dream.sql req @@ fun db ->
    Database.Follows.is_following ~author:current_user ~target:target_user db
    |> map_err (fun e -> `DatabaseError (Caqti_error.show e)) in
  match is_following with
  | false ->
    let id = Uuidm.v `V4 in
    let* _follow =
      Dream.sql req @@
      Database.Follows.create
        ~public_id:(Uuidm.to_string id)
        ~url:("/api/follows/" ^ (Uuidm.to_string id))
        ~author:current_user
        ~target:target_user
        ~pending:false
        ~created:(Ptime_clock.now ())
      |> map_err (fun e -> `DatabaseError (Caqti_error.show e)) in
    redirect req "/users"
  | true ->
    let* follow =
      Dream.sql req @@
      Database.Follows.find_follow_between
        ~author:current_user
        ~target:target_user
      |> map_err (fun e -> `DatabaseError (Caqti_error.show e)) in
    let* follow = Lwt.return (match follow with None -> Error (`DatabaseError "follow not found") | Some follow -> Ok follow) in
    let* _ =
      Dream.sql req @@
      Database.Follows.delete ~id:(follow.Database.Follows.id)
      |> map_err (fun e -> `DatabaseError (Caqti_error.show e)) in
    redirect req "/users"

(* * Follow remote *)
let handle_follow_remote_user current_user username domain req =
  Worker.send_task Worker.(
    FollowRemoteUser {
      user=current_user;
      username;
      domain
    }
  );
  redirect req "/users"

let handle_users_follow_post req =
  let username = Dream.param req "username" in
  log.debug (fun f -> f "got POST to follow with user %s" username);
  let* current_user =
    let* current_user = current_user req in
    lift_opt ~else_:(fun _ -> `InvalidPermissions ("Attempt to follow user while logged out"))
      current_user
    |> return in
  match String.contains username '@', lazy (String.split_on_char '@' username) with
  | true, lazy (username :: domain)  ->
    let domain = String.concat "@" domain in
    handle_follow_remote_user current_user username domain req
  | _ ->
    handle_follow_local_user current_user username req

(* * Inbox (post) *)
let handle_inbox_post req =
  log.debug (fun f -> f ~request:req "got POST to inbox");
  log.debug (fun f -> f "validating request");
  let* valid_request =
    Http_sig.verify_request
      ~resolve_public_key:Ap_resolver.resolve_public_key req
    |> map_err (fun err -> `ResolverError err) in
  log.debug (fun f -> f "request validation completed with result %b" valid_request);
  let* () =
    if valid_request
    then return_ok ()
    else return (Error (`InvalidSignature)) in
  let username = Dream.param req "username" in
  let* _user = 
    Dream.sql req (Database.LocalUser.find_user ~username)
    |> map_err (fun err -> `DatabaseError (Caqti_error.show err))
    >>= (fun v -> return (lift_opt ~else_:(fun () -> `UserNotFound username) v)) in
  let* body_text = lift_pure (Dream.body req) in
  Configuration.dump_string ~ty:"inbox-post" body_text;
  let* data =
    (Activitypub.Decode.(decode_string obj) body_text)
    |> (function
        | Ok _ as data -> data
        | Error err ->
          if Lazy.force Configuration.debug then
            IO.with_out ~flags:[Open_append; Open_creat] "ocamlot-failed-events.json" (Fun.flip IO.write_line (body_text ^ "\n"));
          Error err)
    |> return
    |> map_err (fun err -> `InvalidActivitypubObject err) in

  log.debug (fun f ->
      f "received activitypub object %a"
        Activitypub.Types.pp_obj data
    );
  log.debug (fun f ->
      f "headers were %s"
        ([%show: (string * string) list] (Dream.all_headers req))
    );

  let* _ =
    match[@warning "-27"] data with
    | `Accept { obj=`Follow { id=follow_id; _ }; id=accept_activity_id; raw=accept_obj; actor; _ } ->
      Worker.send_task Worker.(
          HandleAcceptFollow { follow_id }
        );
      return_ok ()
    | `Follow { id; actor; cc; to_; object_; state; raw } ->
      let lazy user_re = Configuration.Regex.local_user_id_format in
      let* re_matches = Re.exec_opt user_re object_
                        |> lift_opt ~else_:(fun () -> `InvalidData "follow target was not a valid user")
                        |> return in
      let username = Re.Group.get re_matches 1 in
      let* target = Dream.sql req (Database.LocalUser.find_user ~username)
                    |> map_err (fun err -> `DatabaseError (Caqti_error.show err)) in
      let* target = lift_opt ~else_:(fun _ -> `UserNotFound object_) target
                    |> return in
      Worker.send_task Worker.(
          HandleRemoteFollow { id; actor; target; raw }
        );
      return_ok ()
    | `Undo { obj=`Follow { id=follow_id; _ }; _ } ->
      Worker.send_task Worker.(
          HandleUndoFollow { follow_id }
        );
      return_ok ()
    | `Create { obj=`Note note; actor; published; direct_message; _ } ->
      log.debug (fun f -> f "creating post");
      Worker.send_task Worker.(
          CreateRemoteNote { author=actor; direct_message; note }
        );
      return_ok ()
    | `Accept _
    | `Announce _
    | `Block _
    | `Note _
    | `Person _
    | `Undo _
    | `Delete _
    | `Create _ -> return_ok ()
    | `Reboost ({ id; actor; published; obj; raw } as reboost) ->
      log.debug (fun f -> f "received reboost of %s by %s (at %a)"
                    obj actor (Option.pp(Ptime.pp_rfc3339 ())) published);
      let public_id = Configuration.extract_activity_id_from_url obj in
      let* public_id =
        lift_opt public_id
          ~else_:(fun _ ->
              `InvalidData "received reboost addressed to a post not from this instance.")
        |> return in
      let* post =
        Dream.sql req (Database.Posts.lookup_by_public_id ~public_id)
        |> map_err (fun err -> `DatabaseError (Caqti_error.show err)) in
      let* post =
        lift_opt post
          ~else_:(fun _ ->
              `ActivityNotFound "Received reboost for activity that is \
                                 not present on this instance.")
        |> return in
      let published = Option.get_lazy Ptime_clock.now published in
      Worker.send_task Worker.(
          HandleRemoteReboost {
            id; author=actor; target=post; published; raw_data=raw
          }
        );
      log.debug (fun f ->
          f "received reboost %a"
            Activitypub.Types.pp_reboost reboost);
      return_ok ()
    | `Like ({ id; published; actor; obj; raw; _ } as like) ->
      log.debug (fun f -> f "received like");
      let public_id = Configuration.extract_activity_id_from_url obj in
      let* public_id =
        lift_opt public_id
          ~else_:(fun _ ->
              `InvalidData "received like addressed to a post not from \
                            this instance.")
        |> return in
      let* post = Dream.sql req (Database.Posts.lookup_by_public_id ~public_id)
                  |> map_err (fun err -> `DatabaseError (Caqti_error.show err)) in
      let* post =
        lift_opt post
          ~else_:(fun _ ->
              `ActivityNotFound "Received like for activity that is \
                                 not present on this instance.")
        |> return in
      let published = Option.get_lazy Ptime_clock.now published in
      Worker.send_task Worker.(
          HandleRemoteLike { id; author=actor; target=post; published; raw_data=raw }
        );
      log.debug (fun f -> f "received like %a" Activitypub.Types.pp_like like);
      return_ok () in

  json (`Assoc [
      "ok", `List []
    ])

(* * Route *)
let route = 
  Dream.scope "/users" [] [
    Dream.get "" @@ Error_handling.handle_error_html (handle_users_get);
    Dream.get "/:username" @@ (handle_actor_get);

    Dream.get "/:username/edit" @@ Error_handling.handle_error_html (handle_actor_edit_get);
    Dream.post "/:username/edit" @@ Error_handling.handle_error_html (handle_actor_edit_post);

    Dream.post "/:username/follow" @@ Error_handling.handle_error_html (handle_users_follow_post);
    (* Dream.get "/:username/inbox" handle_inbox_get; *)
    Dream.post ":username/inbox" @@ Error_handling.handle_error_json (handle_inbox_post);
    Dream.get "/:username/outbox" handle_outbox_get;
    (* Dream.post "/:username/outbox" handle_outbox_post; *)

    Dream.get "/:username/followers" @@ Error_handling.handle_error_json (handle_followers_get);
    Dream.get "/:username/following" @@ Error_handling.handle_error_json (handle_following_get);
  ]
