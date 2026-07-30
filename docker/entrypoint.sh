#!/bin/sh
set -eu

cd /app

export OR_ROOT="${OR_ROOT:-/usr/local/openresty}"
export LJ_ROOT="${LJ_ROOT:-/usr/local/openresty/luajit}"

for path in \
	app_config.lua \
	nginx.conf \
	nginx_config.lua \
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

runtime_lib_dir="/tmp/rizu-libs"
mkdir -p "$runtime_lib_dir"
for name in lib7z.so libiconv.so libminacalc.so libsqlite3.so
do
	ln -sfn "/app/bin/linux64/$name" "$runtime_lib_dir/$name"
done
export LD_LIBRARY_PATH="$runtime_lib_dir:${LD_LIBRARY_PATH:-$LJ_ROOT/lib}"

mkdir -p \
	logs \
	storages/charts \
	storages/replays \
	temp/client_body \
	temp/proxy \
	temp/fastcgi \
	temp/uwsgi \
	temp/scgi

./luajit -e 'local db = require("ljsqlite3").open(":memory:"); assert(db:rowexec("SELECT sqlite_version()") == "3.53.4"); db:close()'
./luajit -e 'assert(require("chart.scoring.minacalc"))'

exec openresty -p /app -c nginx.conf -g "daemon off;"
