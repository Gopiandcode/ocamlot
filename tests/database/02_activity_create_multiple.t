  $ ./app_launcher.exe test.db activity create id-0 "{ \"bob\": \"epic\" }"
  $ ./app_launcher.exe test.db activity create id-1 "{ \"sally\": 1, \"harry\": [{\"age\": 18, \"barry\": false }] }"
  $ ./app_launcher.exe test.db activity find-by-id id-0
  Some { Operations.Activity.id = "id-0";
         raw_data = `Assoc ([("bob", `String ("epic"))]) }
  $ ./app_launcher.exe test.db activity find-by-id id-1
  Some { Operations.Activity.id = "id-1";
         raw_data =
         `Assoc ([("sally", `Int (1));
                   ("harry",
                    `List ([`Assoc ([("age", `Int (18));
                                      ("barry", `Bool (false))])
                             ]))
                   ])
         }
