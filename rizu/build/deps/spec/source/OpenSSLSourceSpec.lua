local MacOSCross = require("rizu.build.deps.spec.source.MacOSCross")
local Manifest = require("rizu.build.deps.Manifest")

local OpenSSLSourceSpec = {}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
---@param prefix string
---@param prefix_abs string
---@param tc_bin string?
function OpenSSLSourceSpec.add(target, spec, prefix, prefix_abs, tc_bin)
	local openssl = Manifest.openssl_source and Manifest.openssl_source[target]
	if not openssl then
		return
	end
	local archive = "${downloads_dir}/" .. openssl.archive
	local extract = "${deps_dir}/" .. openssl.dir

	if target == "linux" then
		table.insert(spec.steps, {
			id = "linux_openssl",
			kind = "source-build",
			actions = {
				{type = "download", url = openssl.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract},
				{type = "configure", dir = extract, script = "./Configure", args = {"linux-x86_64", "--prefix=" .. prefix_abs, "--openssldir=" .. prefix_abs .. "/ssl", "shared", "zlib", "--with-zlib-include=" .. prefix_abs .. "/include", "--with-zlib-lib=" .. prefix_abs .. "/lib"}},
				{type = "make", dir = extract, args = {"-j$(nproc)"}},
				{type = "make", dir = extract, args = {"install_sw"}},
				{type = "assert_file", path = prefix .. "/lib64/libssl.so.3"},
				{type = "assert_file", path = prefix .. "/lib64/libcrypto.so.3"},
				{type = "copy_exact", src = prefix .. "/lib64/libssl.so.3", dst = "${bin_dir}/libssl.so.3", flags = "-Lf"},
				{type = "copy_exact", src = prefix .. "/lib64/libcrypto.so.3", dst = "${bin_dir}/libcrypto.so.3", flags = "-Lf"},
				{type = "remove", path = "${bin_dir}/libssl.so"},
				{type = "remove", path = "${bin_dir}/libcrypto.so"},
			},
		})
	elseif target == "windows" then
		table.insert(spec.steps, {
			id = "windows_openssl",
			kind = "source-build",
			actions = {
				{type = "download", url = openssl.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract},
				{type = "configure", dir = extract, script = "./Configure", args = {"mingw64", "shared", "--cross-compile-prefix=x86_64-w64-mingw32-", "--prefix=" .. prefix_abs, "--openssldir=" .. prefix_abs .. "/ssl"}},
				{type = "make", dir = extract, args = {"-j$(nproc)"}},
				{type = "make", dir = extract, args = {"install_sw"}},
				{type = "assert_file", path = prefix .. "/bin/libssl-3-x64.dll"},
				{type = "assert_file", path = prefix .. "/bin/libcrypto-3-x64.dll"},
				{type = "copy_exact", src = prefix .. "/bin/libssl-3-x64.dll", dst = "${bin_dir}/libssl-3-x64.dll", flags = "-f"},
				{type = "copy_exact", src = prefix .. "/bin/libcrypto-3-x64.dll", dst = "${bin_dir}/libcrypto-3-x64.dll", flags = "-f"},
			},
		})
	elseif target == "macos" then
		---@cast tc_bin string
		table.insert(spec.steps, {
			id = "macos_openssl",
			kind = "source-build",
			actions = {
				{type = "download", url = openssl.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract},
				{
					type = "configure",
					dir = extract,
					script = "./Configure",
					env = MacOSCross.env(tc_bin),
					args = {
						"darwin64-x86_64-cc",
						"shared",
						"--prefix=" .. prefix_abs,
						"--openssldir=" .. prefix_abs .. "/ssl",
					},
				},
				{type = "make", dir = extract, env = MacOSCross.env(tc_bin), args = {"-j$(nproc)"}},
				{type = "make", dir = extract, env = MacOSCross.env(tc_bin), args = {"install_sw"}},
				{type = "assert_file", path = prefix .. "/lib/libssl.dylib"},
				{type = "assert_file", path = prefix .. "/lib/libcrypto.dylib"},
				{type = "copy_exact", src = prefix .. "/lib/libssl.dylib", dst = "${bin_dir}/libssl.dylib", flags = "-f"},
				{type = "copy_exact", src = prefix .. "/lib/libcrypto.dylib", dst = "${bin_dir}/libcrypto.dylib", flags = "-f"},
			},
		})
	end
end

return OpenSSLSourceSpec
