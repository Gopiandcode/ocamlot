
let home_url =
  lazy begin
    Lazy.force Params.domain
    |> Fun.flip Uri.with_path "/home"
  end

let image_path path = "/images/" ^ path

let image_url path =
  Lazy.force Params.domain
  |> Fun.flip Uri.with_path ("/images/" ^ path)

let user_base_url =
  lazy begin
    Lazy.force Params.domain
    |> Fun.flip Uri.with_path "/users"
  end

let user_profile_picture = function
  | Some path -> image_path path
  | None -> "/static/images/unknown.png"

let user_path username = ("/users/" ^ username)
let user_follow_path username = user_path username ^ "/follow"
let user username = 
  Lazy.force Params.domain
  |> Fun.flip  Uri.with_path (user_path username)

let user_followers_path username = ("/users/" ^ username ^ "/followers")
let user_followers username =
  Lazy.force Params.domain
  |> Fun.flip  Uri.with_path (user_followers_path username)

let user_followers_page username ~start_time ~offset =
  Lazy.force Params.domain
  |> Fun.flip  Uri.with_path (user_followers_path username)
  |> Fun.flip Uri.with_query' ["page", offset;
                               "start", start_time ]

let user_following_path username = ("/users/" ^ username ^ "/following")
let user_following username =
  Lazy.force Params.domain
  |> Fun.flip  Uri.with_path (user_following_path username)

let user_following_page username ~start_time ~offset =
  Lazy.force Params.domain
  |> Fun.flip  Uri.with_path (user_following_path username)
  |> Fun.flip Uri.with_query' ["page", offset;
                               "start", start_time ]

let user_key username =
  Lazy.force Params.domain
  |> Fun.flip  Uri.with_path (user_path username)
  |> Fun.flip Uri.with_fragment (Some "main-key")

(* following pleroma approach, if content-type is html, then return profile page of user *)
let user_profile_page username =
  user username

let user_inbox_path username = ("/users/" ^ username ^ "/inbox")
let user_inbox username =
  Lazy.force Params.domain
  |> Fun.flip Uri.with_path (user_inbox_path username)

let user_outbox_path username = ("/users/" ^ username ^ "/outbox")
let user_outbox username =
  Lazy.force Params.domain
  |> Fun.flip Uri.with_path (user_outbox_path username)

let activity_path id = ("/activity/" ^ id)
let activity_base_endpoint = lazy begin
  Lazy.force Params.domain
  |> Fun.flip Uri.with_path ("/activity")
end

let post_path id = ("/post/" ^ id)
let post id = Lazy.force Params.domain |> Fun.flip Uri.with_path (post_path id)

let remote_post_path url =
  Uri.add_query_param
    (Uri.with_path Uri.empty "/post/remote")
    ("url", [url])
let remote_post_toast url =
  Uri.add_query_param (remote_post_path url)
    ("action", ["toast"])
let remote_post_cheer url =
  Uri.add_query_param (remote_post_path url)
    ("action", ["cheer"])

let write_post_path = Uri.with_path Uri.empty "/write"
let write_reply_path url =
  Uri.add_query_param write_post_path ("in-reply-to", [url])


let activity_endpoint id =
  Lazy.force Params.domain
  |> Fun.flip Uri.with_path (activity_path id)

let api_base_path = lazy begin
  Lazy.force Params.domain
  |> Fun.flip Uri.with_path "api"
end

let node_info_path = lazy begin
  Lazy.force Params.domain
  |> Fun.flip Uri.with_path "/nodeinfo/2.0"
end
