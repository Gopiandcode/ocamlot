open Containers
open Common

let req_post ~headers url body =
  let body = Cohttp_lwt.Body.of_string body in
  try
    let+ pair =
      Cohttp_lwt_unix.Client.post
        ~headers
        ~body
        url in
    Lwt_result.return pair
  with exn -> Lwt.return (Result.of_exn exn)

let req ~headers url =
  try
    let+ pair =
      Cohttp_lwt_unix.Client.get
        ~headers:(Cohttp.Header.of_list headers)
        url in
    Lwt_result.return pair
  with exn -> Lwt.return (Result.of_exn exn)

let signed_req f (key_id, priv_key) uri body_str =
  let current_time = Ptime_clock.now () in
  let headers =
    Http_sig.build_signed_headers
      ~current_time ~method_:"POST" ~body_str
      ~headers:(Http_sig.StringMap.of_list [
        "Content-Type", APConstants.ContentType.ld_json_activity_streams
      ]) ~key_id ~priv_key ~uri
    |> Cohttp.Header.of_list in
  f ~headers uri body_str

let signed_post key uri body =
  signed_req req_post key uri body

let activity_req ?(headers=[]) url =
  let activity_header =
    ("Accept", APConstants.ContentType.activity_json) in
  req ~headers:(activity_header :: headers) url

let json_rd_req ?(headers=[]) url =
  let json_rd_header =
    ("Accept", APConstants.Webfinger.json_rd) in
  req ~headers:(json_rd_header :: headers) url

let lookup_request url =
  (* NOTE: Not obvious, but you need to specify accept headers, else pleroma will return html *)
  let+! (_resp, body) = activity_req (Uri.of_string url) in
  let+! actor = Cohttp_lwt.Body.to_string body
                |> Lwt.map Activitypub.Decode.(decode_string person) in
  let pub_key =
    actor.public_key.pem
    |> Cstruct.of_string
    |> X509.Public_key.decode_pem
    |> Result.map_err (fun (`Msg err) -> err) in
  Lwt.return pub_key

let resolve_remote_user ~username ~domain db : (Database.RemoteUser.t, string) Lwt_result.t =
  let extract_self_link query =
    query.Activitypub.Types.Webfinger.links
    |> List.find_map (function
        Activitypub.Types.Webfinger.Self (
          (`ActivityJson | `ActivityJsonLd | `Json), url
        ) -> Some (Uri.of_string url)
      | _ -> None)
    |> Result.of_opt
    |> Lwt.return in

  let+! result = Database.RemoteUser.lookup_remote_user_by_address ~username ~domain db in
  match result with
    Some v -> Lwt.return_ok v
  | None ->
    (* remote user not found *)
    (* webfinger to find user url *)
    let+! remote_user_url =
      let webfinger_uri = 
        Format.sprintf "https://%s/.well-known/webfinger?resource=acct:%s@%s"
          domain username domain
        |> Uri.of_string in
      let+! (resp, body) = json_rd_req webfinger_uri in
      Dream.log "response to webfinger was %a" Cohttp.Response.pp_hum resp;
      let+ body = Cohttp_lwt.Body.to_string body in
      let+! query_res = body
                        |> Activitypub.Decode.(decode_string Webfinger.query_result)
                        |> Lwt.return in
      extract_self_link query_res in
    (* retrieve json *)
    let+! (resp, body) = activity_req remote_user_url in
    Dream.log "response to retrieving data was %a" Cohttp.Response.pp_hum resp;
    let+ body = Cohttp_lwt.Body.to_string body in
    let+! person_res = body
                       |>  Activitypub.Decode.(decode_string person)
                       |> Lwt.return in
    Dream.log "remote user was %a" Activitypub.Types.pp_person person_res;
    let+! remote_instance = Database.RemoteInstance.create_instance domain db in
    let+! () = Database.RemoteInstance.record_instance_reachable remote_instance db in
    let+! username = person_res.preferred_username
                     |> Result.of_opt
                     |> Lwt.return in
    let+! url = person_res.url
                |> Result.of_opt
                |> Lwt.return in
    Database.RemoteUser.create_remote_user
      ?display_name:person_res.name
      ~inbox:person_res.inbox
      ~outbox:person_res.outbox
      ?followers:person_res.followers
      ?following:person_res.following
      ?summary:person_res.summary
      ~public_key_pem:person_res.public_key.pem
      ~username
      ~instance:(Database.RemoteInstance.self remote_instance)
      ~url:url db

let build_follow_request config local remote db =
  let id = Database.Activity.fresh_id () in
  let local_actor_url = 
    Database.LocalUser.username local
    |> Configuration.Url.user config
    |> Uri.to_string in
  let remote_actor_url = Database.RemoteUser.url remote in
  let follow_request =
    let id =
      Database.Activity.id_to_string id
      |> Configuration.Url.activity_endpoint config
      |> Uri.to_string in
    Activitypub.Types.{ id; actor=local_actor_url;
      cc = []; to_ = [ remote_actor_url ];
      object_=remote_actor_url; state = Some `Pending; }  in
  let data = Activitypub.Encode.follow follow_request in
  let+! _ =
    let+! author = Database.Actor.of_local (Database.LocalUser.self local) db in
    let+! target = Database.Actor.of_remote (Database.RemoteUser.self remote) db in
    Database.Follow.create_follow
      ~url:(Configuration.Url.activity_endpoint config (Database.Activity.id_to_string id)
            |> Uri.to_string)
      ~public_id:(Database.Activity.id_to_string id)
      ~author ~target ~pending:true
      ~created:(CalendarLib.Calendar.now ()) db in
  let+! _ = Database.Activity.create ~id ~data db in
  Lwt_result.return (data |> Yojson.Safe.to_string)

let follow_remote_user config
      (local: Database.LocalUser.t)
      ~username ~domain db: (unit,string) Lwt_result.t =
  let+! remote = resolve_remote_user ~username ~domain db in
  let+! follow_request = build_follow_request config local remote db in
  let uri = Database.RemoteUser.inbox remote in
  let key_id =
    Database.LocalUser.username local
    |> Configuration.Url.user_key config
    |> Uri.to_string in
  let priv_key =
    Database.LocalUser.privkey local in
  let+! resp, _  = signed_post (key_id, priv_key) uri follow_request in
  match resp.status with
  | `OK -> Lwt_result.return ()
  | _ -> Lwt_result.fail "request failed"

