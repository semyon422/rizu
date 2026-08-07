#!/bin/sh
set -eu

cd /app

export OR_ROOT="${OR_ROOT:-/usr/local/openresty}"
export LJ_ROOT="${LJ_ROOT:-/usr/local/openresty/luajit}"

for path in \
	bin/linux64/lib7z.so \
	bin/linux64/libiconv.so \
	bin/linux64/libminacalc.so \
	tree/lib/lua/5.1/socket/core.so \
	tree/share/lua/5.1/socket.lua
do
	if [ ! -e "$path" ]; then
		echo "missing prebuilt compute artifact: $path" >&2
		exit 1
	fi
done

runtime_lib_dir="/tmp/rizu-libs"
mkdir -p "$runtime_lib_dir"
for name in lib7z.so libiconv.so libminacalc.so
do
	ln -sfn "/app/bin/linux64/$name" "$runtime_lib_dir/$name"
done
export LD_LIBRARY_PATH="$runtime_lib_dir:${LD_LIBRARY_PATH:-$LJ_ROOT/lib}"

exec ./luajit sea/compute/worker.lua
