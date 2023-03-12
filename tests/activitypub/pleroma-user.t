  $ ./decoder.exe user resources/pleroma-user.json
  { Types.id = "https://pleroma.ocamlot.xyz/users/sally";
    name = (Some "wally");
    url = (Some "https://pleroma.ocamlot.xyz/users/sally");
    preferred_username = (Some "sally");
    inbox = "https://pleroma.ocamlot.xyz/users/sally/inbox";
    outbox = "https://pleroma.ocamlot.xyz/users/sally/outbox";
    summary = (Some "");
    public_key =
    { Types.id = "https://pleroma.ocamlot.xyz/users/sally#main-key";
      owner = "https://pleroma.ocamlot.xyz/users/sally";
      pem =
      "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnroLioMlVFNcwt6GQURE\njjipstRKAXhgVjhOlIi95xnaXEZFe9FOQcswp4OsfD+luLC6pp42ZojEuZAf+8u9\nInRIWyFlRFjpMsZjsDdsmFhNUqMoFR7iLZ0a2KiqBV4BMlSyqIAeDem7xEIQxNym\nFo0PiNCq5qNV33IQ8MUMyItyJy/Gssc7sAjJijh0rmlTVMqacj1jcRM66I+zsun4\nw6gqrFuVYt3GyxkNDfQ+lEzjf4zMiSVnhkaYhA+YwMX90OF47h92PAWv8hh1FwDA\nzI4U0fJ2RJZJoDxAhg4Tx7LPaGBfofSiOL1vYYSCRa3jRTdhSqjHFviqODSWsTUd\n3wIDAQAB\n-----END PUBLIC KEY-----\n\n"
      };
    manually_approves_followers = false; discoverable = false;
    followers = (Some "https://pleroma.ocamlot.xyz/users/sally/followers");
    following = (Some "https://pleroma.ocamlot.xyz/users/sally/following");
    icon =
    (Some "https://pleroma.ocamlot.xyz/media/e090d869-fd54-4f12-b32c-5e6415736903/wallhaven-qzdqvr.jpg");
    raw =
    {
      "@context": [
        "https://www.w3.org/ns/activitystreams",
        "https://pleroma.ocamlot.xyz/schemas/litepub-0.1.jsonld",
        { "@language": "und" }
      ],
      "alsoKnownAs": [],
      "attachment": [],
      "capabilities": { "acceptsChatMessages": true },
      "discoverable": false,
      "endpoints": {
        "oauthAuthorizationEndpoint": "https://pleroma.ocamlot.xyz/oauth/authorize",
        "oauthRegistrationEndpoint": "https://pleroma.ocamlot.xyz/api/v1/apps",
        "oauthTokenEndpoint": "https://pleroma.ocamlot.xyz/oauth/token",
        "sharedInbox": "https://pleroma.ocamlot.xyz/inbox",
        "uploadMedia": "https://pleroma.ocamlot.xyz/api/ap/upload_media"
      },
      "featured": "https://pleroma.ocamlot.xyz/users/sally/collections/featured",
      "followers": "https://pleroma.ocamlot.xyz/users/sally/followers",
      "following": "https://pleroma.ocamlot.xyz/users/sally/following",
      "icon": {
        "type": "Image",
        "url": "https://pleroma.ocamlot.xyz/media/e090d869-fd54-4f12-b32c-5e6415736903/wallhaven-qzdqvr.jpg"
      },
      "id": "https://pleroma.ocamlot.xyz/users/sally",
      "inbox": "https://pleroma.ocamlot.xyz/users/sally/inbox",
      "manuallyApprovesFollowers": false,
      "name": "wally",
      "outbox": "https://pleroma.ocamlot.xyz/users/sally/outbox",
      "preferredUsername": "sally",
      "publicKey": {
        "id": "https://pleroma.ocamlot.xyz/users/sally#main-key",
        "owner": "https://pleroma.ocamlot.xyz/users/sally",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnroLioMlVFNcwt6GQURE\njjipstRKAXhgVjhOlIi95xnaXEZFe9FOQcswp4OsfD+luLC6pp42ZojEuZAf+8u9\nInRIWyFlRFjpMsZjsDdsmFhNUqMoFR7iLZ0a2KiqBV4BMlSyqIAeDem7xEIQxNym\nFo0PiNCq5qNV33IQ8MUMyItyJy/Gssc7sAjJijh0rmlTVMqacj1jcRM66I+zsun4\nw6gqrFuVYt3GyxkNDfQ+lEzjf4zMiSVnhkaYhA+YwMX90OF47h92PAWv8hh1FwDA\nzI4U0fJ2RJZJoDxAhg4Tx7LPaGBfofSiOL1vYYSCRa3jRTdhSqjHFviqODSWsTUd\n3wIDAQAB\n-----END PUBLIC KEY-----\n\n"
      },
      "summary": "",
      "tag": [],
      "type": "Person",
      "url": "https://pleroma.ocamlot.xyz/users/sally",
      "vcard:bday": null
    } }
