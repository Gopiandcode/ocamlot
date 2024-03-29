open Containers
open Common

let log = Logging.add_logger "worker"

let lift_database_error res =
  map_err (fun err -> `DatabaseError (Caqti_error.show err)) res
let lift_resolver_error res =
  map_err (fun err -> `ResolverError err) res

let with_pool pool f = Caqti_lwt.Pool.use f pool

let extract_local_target_link pool to_ =
  let lazy local_user_regex =
    Configuration.Regex.local_user_id_format in
  if String.equal to_ Activitypub.Constants.ActivityStreams.public
  then return_ok None
  else match Re.exec_opt local_user_regex to_ with
    | Some group ->
      let username = Re.Group.get group 1 in
      let* local_user =
        with_pool pool @@ fun db ->
        Database.LocalUser.find_user ~username db
        |> lift_database_error in
      begin match local_user with
      | None -> return_ok None
      | Some local_user ->
        let* user =
          with_pool pool @@ fun db ->
          Database.Actor.create_local_user ~local_id:(local_user.Database.LocalUser.id) db
          |> lift_database_error in
        return_ok (Some user)
      end
    | None ->
      return_ok None

let handle_error res =
  Lwt.bind res (function
    | Ok _ -> Lwt.return ()
    | Error (#Caqti_error.t as err) ->
      let _, msg, details =
        Error_handling.extract_error_details
          (`DatabaseError (Caqti_error.show err)) in
      log.warning (fun f -> f "worker error: %s" msg);
      log.debug (fun f -> f "worker error details: %s" details);
      Lwt.return ()
    | Error err ->
      let _, msg, details = Error_handling.extract_error_details err in
      log.warning (fun f -> f "worker error: %s" msg);
      log.debug (fun f -> f "worker error details: %s" details);
      Lwt.return ()
  )
