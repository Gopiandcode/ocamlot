(lang dune 3.0)
(cram enable)
(generate_opam_files true)
(implicit_transitive_deps false)

(license AGPL-3.0-or-later)
(maintainers "The OCamlot developers")

(package (name ocamlot)
 (authors "The OCamlot developers")
 (homepage "https://ocamlot.xyz")
 (bug_reports "https://ocamlot.xyz/bug-reports")
 (synopsis "A lightweight activitypub server in OCaml")
 (description "OCamlot is a small OCaml library that provides a robust and efficient activitypub server.")
 (depends
   alcotest alcotest-lwt

   containers
   ptime

   (mirage-crypto-rng (>= 0.11.0))
   (mirage-crypto-rng-lwt (>= 0.11.0))
   argon2

   cohttp cohttp-lwt cohttp-lwt-unix

   caqti
   caqti-driver-sqlite3 caqti-driver-postgresql
   caqti-type-calendar

   conan conan-database

   uuidm

   dream
   tyxml
   uri

   decoders
   decoders-yojson
   yojson

   ppxlib
   ppx_deriving

   jwto

   angstrom
   re

  (omd (= 2.0.0~alpha3))
   crunch ppx_blob

   inotify))
