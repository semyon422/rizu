#!/bin/sh
set -eu
umask 077
cd /app

export OR_ROOT="${OR_ROOT:-/usr/local/openresty}"
export LJ_ROOT="${LJ_ROOT:-/usr/local/openresty/luajit}"

for path in \
	/router-state/config.lua \
	/router-state/network.lua \
	bin/linux64/libsqlite3.so \
	bin/linux64/libssl.so.3 \
	bin/linux64/libcrypto.so.3 \
	tree/lib/lua/5.1/socket/core.so \
	tree/lib/lua/5.1/ssl.so \
	tree/share/lua/5.1/socket.lua \
	tree/share/lua/5.1/ssl.lua \
	resources/certs/cacert.pem
do
	if [ ! -f "$path" ]; then
		echo "missing AI router runtime artifact or config: $path" >&2
		exit 1
	fi
done

if [ ! -w /router-state ]; then
	echo "AI router state must be writable by container user $(id -u):$(id -g)" >&2
	exit 1
fi
for path in /router-state/router.db /router-state/router.db-wal /router-state/router.db-shm
do
	if [ -e "$path" ] && [ ! -w "$path" ]; then
		echo "AI router SQLite file is not writable: $path" >&2
		exit 1
	fi
done

runtime_lib_dir="/tmp/rizu-router-libs"
mkdir -p "$runtime_lib_dir"
for name in libsqlite3.so libssl.so.3 libcrypto.so.3; do
	ln -sfn "/app/bin/linux64/$name" "$runtime_lib_dir/$name"
done
export LD_LIBRARY_PATH="$runtime_lib_dir:${LD_LIBRARY_PATH:-$LJ_ROOT/lib}"

./luajit - <<'LUA'
require("docker.AiRouterConfig").load()
assert(require("ssl"))
local ffi = require("ffi")
ffi.cdef("const char *OpenSSL_version(int t);")
local version = ffi.string(ffi.load("libcrypto.so.3").OpenSSL_version(0))
assert(version:match("^OpenSSL 3%.5%.7 "), "AI router requires bundled OpenSSL 3.5.7; got " .. version)
local db = require("ljsqlite3").open(":memory:")
assert(db:rowexec("SELECT sqlite_version()") == "3.53.4")
db:close()
LUA
exec ./luajit aqua/ai/router/proxy.lua /router-state/config.lua
