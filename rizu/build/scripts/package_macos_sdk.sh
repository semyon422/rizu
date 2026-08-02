#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
	echo "usage: $0 <osxcross-dir> <xcode.xip> <sdk-version> <output>" >&2
	exit 2
fi

osxcross_dir=$(realpath "$1")
xcode_xip=$(realpath "$2")
sdk_version=$3
output=$(realpath -m "$4")
work_dir="$osxcross_dir/build/rizu-sdk-$sdk_version"
content="$work_dir/Content"
payload_dir="$work_dir/payload"
sdk_name="MacOSX$sdk_version.sdk"
sdk_source_name="MacOSX.sdk"
sdk_path="Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/$sdk_source_name"
libcxx_path="Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1"

cleanup() {
	rm -rf "$work_dir"
}
trap cleanup EXIT

rm -rf "$work_dir"
mkdir -p "$payload_dir" "$(dirname "$output")"

"$osxcross_dir/target/bin/xar" -xf "$xcode_xip" -C "$work_dir" Content

cd "$payload_dir"
"$osxcross_dir/target/SDK/tools/bin/pbzx" -n "$content" |
	cpio -idm --quiet \
		"./$sdk_path/*" \
		"./$libcxx_path/*"

mv "$sdk_path" "$sdk_name"
mkdir -p "$payload_dir/$sdk_name/usr/include/c++"
mv "$libcxx_path" "$payload_dir/$sdk_name/usr/include/c++/v1"
rm -rf "$payload_dir/Xcode.app"

tar -cf - "$sdk_name" | xz -5 -T0 > "$output"
