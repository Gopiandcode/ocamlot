# OCamlot - An OCaml Activitypub Server


## Development Setup

To develop OCamlot locally, we provide a docker-compose file for
setting up a network with a running OCamlot (port 7331) and pleroma
(port 4000) instance. The two containers are connected through a
network in which the OCamlot server can be found under the domain name
`testing.ocamlot.xyz` and the Pleroma server can be found under the
domain name `pleroma.ocamlot.xyz`. (Note: because there is no easy way
of updating the CA store that elixir uses, you may need to patch your
local copy of pleroma to disable certification verification for
interaction between the two containers to work).

*You will need docker-compose and docker*

1. Clone a copy of pleroma to the `tests/integration_test/` directory:

```bash
git clone -b stable https://git.pleroma.social/pleroma/pleroma ./tests/integration_test/pleroma
```

2. Change directory into the `tests/integration_test/` directory:

```bash
cd ./tests/integration_test/
```

3. Run `docker-compose build` with the local docker-compose file:

```bash
docker-compose -f ./docker-compose.local.yml build
```

4. Run `docker-compose up` with the local docker-compose file:

```bash
docker-compose -f ./docker-compose.local.yml up
```

5. (optional), if you want to update the OCamlot server after making some changes locally, do the following:

   - 5.1. Find out the name of the OCamlot server container using `docker container list`
   - 5.2. Attach to the OCamlot container using `docker container exec -it <container-id> bash`
   - 5.3. Kill the running OCamlot process using `pkill -9 main.exe`
   - 5.4. Run `dune build` and then `dune exec ./bin/main.exe -d testingl.ocamlot.xyz -D`
