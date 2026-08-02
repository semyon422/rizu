#!/bin/sh
set -eu

cd /app

export OR_ROOT="${OR_ROOT:-/usr/local/openresty}"
export LJ_ROOT="${LJ_ROOT:-/usr/local/openresty/luajit}"

state_dir="${RIZU_SERVER_STATE_DIR:-server-state}"
export NGINX_CONFIG_PATH="/app/$state_dir/nginx_config.lua"

for path in \
	"$state_dir/app_config.lua" \
	"$state_dir/nginx.conf" \
	"$state_dir/nginx_config.lua" \
	bin/linux64/lib7z.so \
	bin/linux64/libiconv.so \
	bin/linux64/libminacalc.so \
	bin/linux64/libsqlite3.so \
	tree/lib/lua/5.1/bcrypt.so \
	tree/share/lua/5.1/resty/nats/client.lua
do
	if [ ! -e "$path" ]; then
		echo "missing prebuilt runtime artifact: $path" >&2
		exit 1
	fi
done

if [ ! -w "/app/$state_dir" ]; then
	echo "server state is not writable by container user $(id -u):$(id -g): /app/$state_dir" >&2
	exit 1
fi
if [ -e "$state_dir/server.db" ] && [ ! -w "$state_dir/server.db" ]; then
	echo "SQLite database is not writable by container user $(id -u):$(id -g): /app/$state_dir/server.db" >&2
	exit 1
fi

runtime_lib_dir="/tmp/rizu-libs"
mkdir -p "$runtime_lib_dir"
for name in lib7z.so libiconv.so libminacalc.so libsqlite3.so
do
	ln -sfn "/app/bin/linux64/$name" "$runtime_lib_dir/$name"
done
export LD_LIBRARY_PATH="$runtime_lib_dir:${LD_LIBRARY_PATH:-$LJ_ROOT/lib}"

mkdir -p \
	"$state_dir/logs" \
	"$state_dir/storages/charts" \
	"$state_dir/storages/replays" \
	"$state_dir/temp/client_body" \
	"$state_dir/temp/proxy" \
	"$state_dir/temp/fastcgi" \
	"$state_dir/temp/uwsgi" \
	"$state_dir/temp/scgi"

./luajit -e 'local db = require("ljsqlite3").open(":memory:"); assert(db:rowexec("SELECT sqlite_version()") == "3.53.4"); db:close()'
./luajit -e 'assert(require("chart.scoring.minacalc"))'

exec openresty -p /app -c "$state_dir/nginx.conf" -g "daemon off;"
