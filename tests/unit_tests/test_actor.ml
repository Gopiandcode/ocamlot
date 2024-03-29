open Testing_utils.Common
module T = Testing_utils.Lwt.Make (struct let name = "actor" end);;

T.add_test "can create remote user" @@ with_db @@ fun db ->
let+ instance = Database.RemoteInstance.create_instance "ocamlot.xyz" db in
let instance = Result.get_ok instance in
let* user = Database.RemoteUser.create_remote_user
    ~username:"atestaccount"
    ~instance:(Database.RemoteInstance.self instance)
    ~url:"https://ocamlot.xyz/users/atestaccount"  ~public_key_pem:""
    db
  >|= Database.RemoteUser.self in
let+ actor = Database.Actor.of_remote user db in
ret begin
check_is_ok actor
end
;;

T.add_test "can create remote user twice" @@ with_db @@ fun db ->
let+ instance = Database.RemoteInstance.create_instance "ocamlot.xyz" db in
let instance = Result.get_ok instance in
let* user = Database.RemoteUser.create_remote_user
    ~username:"atestaccount"
    ~instance:(Database.RemoteInstance.self instance)
    ~url:"https://ocamlot.xyz/users/atestaccount"  ~public_key_pem:""
    db >|= Database.RemoteUser.self in
let* _ = Database.Actor.of_remote user db in
let+ actor2 = Database.Actor.of_remote user db in
ret begin
check_is_ok actor2
end
;;

T.add_test "can resolve remote users" @@ with_db @@ fun db ->
let+ instance = Database.RemoteInstance.create_instance "ocamlot.xyz" db in
let instance = Result.get_ok instance in
let* user = Database.RemoteUser.create_remote_user
              ~username:"atestaccount"
              ~instance:(Database.RemoteInstance.self instance)
              ~url:"https://ocamlot.xyz/users/atestaccount"  ~public_key_pem:""
              db >|= Database.RemoteUser.self in
let+ link = Database.Actor.of_remote user db in
let link = Result.get_ok link in
let+ remote_user_resolved = Database.Link.resolve link db in
ret begin
  check_is_ok remote_user_resolved
end
;;

T.add_test "can resolve remote users correctly" @@ with_db @@ fun db ->
let* instance = Database.RemoteInstance.create_instance "ocamlot.xyz" db in
let* remote_user = Database.RemoteUser.create_remote_user
    ~username:"atestaccount"
    ~instance:(Database.RemoteInstance.self instance)
    ~url:"https://ocamlot.xyz/users/atestaccount"  ~public_key_pem:""
    db in
let ru = Database.RemoteUser.self remote_user in
let+ link = Database.Actor.of_remote ru db in
let link = Result.get_ok link in
let* remote_user_resolved = Database.Link.resolve link db in
ret @@ match remote_user_resolved with
| Database.Actor.Remote user ->
  check_string_eq
    ~expected:(Database.RemoteUser.username remote_user)
    (Database.RemoteUser.username user)
| Database.Actor.Local _ ->
  failwith "expected a local instance, retrieved a global one"
;;



T.add_test "can create local user" @@ with_db @@ fun db ->
let* local_user = Database.LocalUser.create_user ~username:"example" ~password:"areallygoodpassword" 
                    db >|= Database.LocalUser.self in
let+ actor = Database.Actor.of_local local_user db in
ret begin
  check_is_ok actor
end
;;

T.add_test "can create local user twice" @@ with_db @@ fun db ->
let* local_user = Database.LocalUser.create_user ~username:"example" ~password:"areallygoodpassword" db
  >|= Database.LocalUser.self in
let+ _ = Database.Actor.of_local local_user db in
let+ actor = Database.Actor.of_local local_user db in
ret begin
check_is_ok actor
end
;;

T.add_test "can resolve local users" @@ with_db @@ fun db ->
let* local_user = Database.LocalUser.create_user ~username:"example" ~password:"areallygoodpassword" db
  >|= Database.LocalUser.self in
let+ link = Database.Actor.of_local local_user db in
let link = Result.get_ok link in
let+ local_user_resolved = Database.Link.resolve link db in
ret begin
  check_is_ok local_user_resolved
end
;;

T.add_test "can resolve local users correctly" @@ with_db @@ fun db ->
let* lu = Database.LocalUser.create_user ~username:"example" ~password:"areallygoodpassword" db in
let local_user = Database.LocalUser.self lu in
let+ link = Database.Actor.of_local local_user db in
let link = Result.get_ok link in
let* local_user_resolved = Database.Link.resolve link db in
ret @@ match local_user_resolved with
| Database.Actor.Local user ->
  check_string_eq ~expected:(Database.LocalUser.username lu) (Database.LocalUser.username user)
| Database.Actor.Remote _ ->
  failwith "expected a local instance, retrieved a global one"
;;


let () =
  Mirage_crypto_rng_lwt.initialize (module Mirage_crypto_rng.Fortuna);
  T.run ()
