local Dd32Spec = require("rizu.build.deps.spec.common.Dd32Spec")
local MacOSCross = require("rizu.build.deps.spec.source.MacOSCross")
local table_util = require("table_util")
local Manifest = require("rizu.build.deps.Manifest")

local FFTWSourceSpec = {}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
---@param prefix string
---@param prefix_abs string
---@param tc_bin string?
function FFTWSourceSpec.add(target, spec, prefix, prefix_abs, tc_bin)
	local fftw = Manifest.fftw_source and Manifest.fftw_source[target]
	if not fftw then
		return
	end
	local archive = "${downloads_dir}/" .. fftw.archive
	local extract = "${deps_dir}/" .. fftw.dir

	if target == "linux" then
		table.insert(spec.steps, {
			id = "linux_fftw",
			kind = "source-build",
			actions = {
				{type = "download", url = fftw.url, dest = archive},
				{type = "extract", format = "tar.gz", archive = archive, dest = extract},
				{type = "cmake_configure", src_dir = extract, build_dir = extract .. "/build-cmake", args = {"-DBUILD_SHARED_LIBS=ON", "-DCMAKE_POLICY_VERSION_MINIMUM=4.0"}},
				{type = "cmake_build", build_dir = extract .. "/build-cmake", args = {"-j$(nproc)"}},
				{type = "assert_file", path = extract .. "/build-cmake/libfftw3.so"},
				{type = "copy_exact", src = extract .. "/build-cmake/libfftw3.so", dst = "${bin_dir}/libfftw3.so", flags = "-L"},
			},
		})
		return
	end

	local actions = {
		{type = "download", url = fftw.url, dest = archive},
		{type = "extract", format = "tar.gz", archive = archive, dest = extract},
	}
	Dd32Spec.addSetup(actions)

	if target == "windows" then
		table_util.append(actions, {
			{
				type = "configure",
				dir = extract,
				env = Dd32Spec.env(),
				args = {"--host=x86_64-w64-mingw32", "--prefix=" .. prefix_abs, "--enable-shared", "--disable-static", "CFLAGS=-O2"},
			},
			{type = "make", dir = extract, args = {"-j$(nproc)"}},
			{type = "make", dir = extract, args = {"install"}},
			{type = "assert_file", path = prefix .. "/bin/libfftw3-3.dll"},
			{type = "copy_exact", src = prefix .. "/bin/libfftw3-3.dll", dst = "${bin_dir}/libfftw3-3.dll", flags = "-f"},
		})
	elseif target == "macos" then
		---@cast tc_bin string
		table_util.append(actions, {
			{
				type = "configure",
				dir = extract,
				env = MacOSCross.envWithDd(tc_bin),
				args = {"--host=" .. MacOSCross.DARWIN_TRIPLE, "--prefix=" .. prefix_abs, "--enable-shared", "--disable-static", "CFLAGS=-O2 -fPIC"},
			},
			{type = "make", dir = extract, env = MacOSCross.env(tc_bin), args = {"-j$(nproc)"}},
			{type = "make", dir = extract, env = MacOSCross.env(tc_bin), args = {"install"}},
			{type = "assert_file", path = prefix .. "/lib/libfftw3.dylib"},
			{type = "copy_exact", src = prefix .. "/lib/libfftw3.dylib", dst = "${bin_dir}/libfftw3.dylib", flags = "-Lf"},
		})
	end

	table.insert(spec.steps, {
		id = target .. "_fftw",
		kind = "source-build",
		actions = actions,
	})
end

return FFTWSourceSpec
