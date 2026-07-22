# Bootstrap and Tooling Guide

## Goal

This guide is the starting point for preparing a fresh checkout for Rizu game development, the `sea` web server, standalone `aqua` tools, and release builds. Run commands from the repository root unless stated otherwise.

## Fresh Checkout

Clone the repository with its submodules:

```bash
git clone --recurse-submodules <repository-url> rizu
cd rizu
```

For a small deployment checkout without history:

```bash
git clone --depth 1 --single-branch --recurse-submodules --shallow-submodules <repository-url> rizu
cd rizu
```

Repair or initialize submodules in an existing checkout with:

```bash
git submodule update --init --recursive
```

The project targets LuaJIT 2.1. `./luajit`, the test runner, and `rizu/build/make.lua` all need a `luajit` executable in `PATH`. The server dependency setup additionally expects OpenResty in one of these locations:

- `/usr/local/openresty`
- `/opt/openresty`
- `/usr/local/opt/openresty`

## Choose a Setup Path

### Full game and release build environment

On Debian or Ubuntu, first make LuaJIT available, then let the build system install its host and cross-compilation packages:

```bash
sudo apt-get update
sudo apt-get install -y git ca-certificates luajit
./rizu/build/make.lua setup
./rizu/build/make.lua build_target linux
```

`setup` uses `sudo apt-get` and installs the compilers, headers, archive tools, and cross-compilers used by all build targets. It does not install OpenResty or LuaRocks.

Useful build commands:

```bash
./rizu/build/make.lua help
./rizu/build/make.lua status all
./rizu/build/make.lua prefetch all
./rizu/build/make.lua luajit linux
./rizu/build/make.lua build_target linux
./rizu/build/make.lua build_target windows
./rizu/build/make.lua build_target macos
./rizu/build/make.lua repo
./rizu/build/make.lua package
```

See [rizu/build/spec.md](rizu/build/spec.md) for the build graph and output layout. `clean` removes generated output, so inspect its scopes with `help` before using it.

### Web server and full LuaRocks environment

Install OpenResty system-wide first. Then install LuaRocks into the ignored repository-local `tree/` and install the project's rocks:

```bash
./aqua/env/install_luarocks
./install
```

`aqua/env/install_luarocks` downloads and builds the pinned LuaRocks release against OpenResty's LuaJIT. `./install` installs the Lua modules used by the web server and tools, then creates `logs/`, `temp/`, and storage directories. If `./install` reports `luarocks: command not found`, run `./aqua/env/install_luarocks` first.

To use OpenResty's LuaJIT and the local rock tree directly in the current shell:

```bash
source ./aqua/env/openresty_setenv
```

The environment change only affects the current shell. Shell scripts such as `./install`, `./openresty`, and `./sea-cli` load it themselves.

Create the ignored runtime configuration files without overwriting existing ones:

```bash
test -e nginx_config.lua || cp aqua/web/nginx/nginx_config.lua nginx_config.lua
test -e app_config.lua || cp sea/app/AppConfig.lua app_config.lua
test -e my.cnf || cp my.cnf.example my.cnf
```

Edit the copies for the deployment. `nginx_config.lua` is the source of truth for the generated OpenResty config; never edit `nginx.conf` directly.

Compile and control the server with:

```bash
./luajit aqua/web/nginx/compile.lua
./openresty start
./openresty reload
./openresty stop
```

The `./openresty` wrapper compiles `nginx.conf` before every operation, so the explicit compile command is mainly useful for validation.

### Standalone OpenAI subscription proxy

The proxy only needs OpenResty/LuaJIT plus three rocks. This avoids installing the full web-server dependency set:

```bash
sudo apt-get install -y build-essential wget ca-certificates libssl-dev
./aqua/env/install_luarocks
source ./aqua/env/openresty_setenv
luarocks install luasocket
luarocks install luaossl
luarocks install luasec
```

Create its ignored configuration from the tracked template:

```bash
mkdir -p userdata
test -e userdata/ai_proxy.lua || cp aqua/ai/openai/proxy_config.example.lua userdata/ai_proxy.lua
```

Replace `replace-with-a-long-random-token` in `userdata/ai_proxy.lua`. The proxy also reads subscription credentials from `userdata/ai_auth.lua` and SOCKS5 routing from `userdata/network.lua`; copy those files from an already configured game installation when bootstrapping a separate server.

Start the loopback-only service with:

```bash
source ./aqua/env/openresty_setenv
./luajit aqua/ai/openai/proxy.lua
```

Keep it bound to `127.0.0.1` when publishing it through an HTTPS reverse proxy. See [aqua/ai/openai/spec.md](aqua/ai/openai/spec.md) and [aqua/ai/openai/nginx_proxy.example.conf](aqua/ai/openai/nginx_proxy.example.conf) for configuration and Nginx requirements.

## Running and Testing

Run the game with the launcher for the host platform:

```bash
./game-appimage
./game-macos
```

On Windows, run `game-win64.bat`.

Run tests with an optional file and method pattern:

```bash
./test
./test rizu/build
./test path/to/Module_test.lua method_pattern
```

Other test entry points are specialized:

- `./test-love` runs tests inside the bundled Linux LÖVE AppImage.
- `./test-macos` runs tests with `/Applications/love.app`.
- `./test-resty` runs tests through OpenResty's `resty` executable.

## Script Reference

| Script | Purpose | Main prerequisite |
| --- | --- | --- |
| `rizu/build/make.lua` | Installs build packages, builds target dependencies, assembles repositories, and packages releases | LuaJIT; Debian/Ubuntu for `setup` |
| `aqua/env/install_luarocks` | Builds the pinned LuaRocks into `tree/` | OpenResty, compiler, `wget` |
| `install` | Installs all project Lua rocks and creates runtime directories | Project-local LuaRocks and OpenResty |
| `aqua/env/luajit_setenv` | Adds `tree/bin` and `tree/lib` to the current shell | Built local LuaJIT tree |
| `aqua/env/openresty_setenv` | Adds OpenResty and the local rock tree to the current shell | OpenResty in a recognized location |
| `luajit` / `luajit.lua` | Runs repository Lua tools with project Lua and native module paths | LuaJIT in `PATH` |
| `openresty` | Compiles the root Nginx config and starts, reloads, or stops OpenResty | OpenResty and runtime configs |
| `aqua/env/openresty` | Base/reference copy of the OpenResty control script; use the root `openresty` wrapper in this checkout | OpenResty and runtime configs |
| `aqua/web/nginx/compile.lua` | Generates `nginx.conf` from `nginx_config.lua` | OpenResty Lua environment |
| `sea-cli` | Runs server maintenance commands with LuaJIT | OpenResty, rocks, `app_config.lua` |
| `sea-cli-resty` | Runs the same maintenance CLI through `resty` | OpenResty, rocks, `app_config.lua` |
| `sea-cli-love` | Runs the same maintenance CLI through LÖVE | LÖVE plus server dependencies |
| `game-appimage` | Starts the bundled Linux game | Built/downloaded Linux binaries |
| `game-macos` | Starts the game with the system LÖVE app | `/Applications/love.app` |
| `game-win64.bat` | Starts the Windows game at high priority | Built/downloaded Windows binaries |
| `test` | Runs the normal LuaJIT test suite with a 2 GB memory limit | LuaJIT and relevant dependencies |
| `test-love`, `test-macos`, `test-resty` | Run tests in alternate runtimes | Matching runtime |
| `bench` | Starts the LÖVE benchmark entry point | LÖVE and Linux native modules |
| `db_dump` | Dumps the `backend` MariaDB database into `backups/` | MariaDB client, configured `my.cnf`, existing `backups/` |
| `db_restore` | Restores a dump into the `backend` database | MariaDB client and configured `my.cnf` |
| `scripts/check_spec_coverage.lua` | Checks specification IDs against Lua source references | LuaJIT and Unix `find` |
| `render_dep_graph` | Renders the legacy dependency graph to `graph.png` | LuaJIT and Graphviz `sfdp` |
| `cloc` | Reports selected source-language statistics | `cloc` and `jq` |
| `git-today` | Summarizes the current Git author's recent work, including submodules | Git and GNU userland tools |

## Generated and Local Files

These paths are expected to remain local or generated:

- `tree/`: local LuaJIT/LuaRocks installation.
- `build/`: downloaded sources, intermediate files, assembled repositories, and packages.
- `nginx.conf`: generated from `nginx_config.lua`.
- `nginx_config.lua`, `app_config.lua`, and `my.cnf`: ignored server configuration.
- `userdata/`: ignored game and AI credentials/configuration.
- `logs/`, `temp/`, and `storages/`: server runtime data.

Do not copy secrets into tracked examples or documentation.
