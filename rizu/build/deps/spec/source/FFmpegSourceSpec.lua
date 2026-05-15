local MacOSCross = require("rizu.build.deps.spec.source.MacOSCross")
local Manifest = require("rizu.build.deps.Manifest")

local FFmpegSourceSpec = {}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
---@param prefix string
---@param prefix_abs string
---@param tc_bin string?
function FFmpegSourceSpec.add(target, spec, prefix, prefix_abs, tc_bin)
	if target ~= "macos" then
		return
	end
	---@cast tc_bin string
	local ffmpeg_src = Manifest.ffmpeg_source and Manifest.ffmpeg_source.macos
	if not ffmpeg_src then
		return
	end
	local archive = "${downloads_dir}/" .. ffmpeg_src.archive
	local extract = "${deps_dir}/" .. ffmpeg_src.dir
	table.insert(spec.steps, {
		id = "macos_ffmpeg_source",
		kind = "source-build",
		actions = {
			{type = "download", url = ffmpeg_src.url, dest = archive},
			{type = "extract", format = "tar.gz", archive = archive, dest = extract},
			{type = "ensure_dir", path = prefix .. "/ffmpeg"},
			{
				type = "configure",
				dir = extract,
				env = MacOSCross.env(tc_bin),
				args = {
					"--prefix=" .. prefix_abs .. "/ffmpeg",
					"--enable-cross-compile",
					"--target-os=darwin",
					"--arch=x86_64",
					"--cc=" .. MacOSCross.cc(tc_bin),
					"--ar=" .. tc_bin .. "/" .. MacOSCross.DARWIN_TRIPLE .. "-ar",
					"--ranlib=" .. tc_bin .. "/" .. MacOSCross.DARWIN_TRIPLE .. "-ranlib",
					"--enable-shared",
					"--disable-static",
					"--disable-programs",
					"--disable-doc",
					"--disable-debug",
					"--disable-asm",
					"--disable-videotoolbox",
				},
			},
			{type = "make", dir = extract, env = MacOSCross.env(tc_bin), args = {"-j$(nproc)"}},
			{type = "make", dir = extract, env = MacOSCross.env(tc_bin), args = {"install", "STRIP=true"}},
			{type = "assert_file", path = prefix .. "/ffmpeg/lib/libavcodec.dylib"},
			{type = "assert_file", path = prefix .. "/ffmpeg/lib/libavformat.dylib"},
			{type = "assert_file", path = prefix .. "/ffmpeg/lib/libavutil.dylib"},
			{type = "assert_file", path = prefix .. "/ffmpeg/lib/libswscale.dylib"},
			{type = "assert_file", path = prefix .. "/ffmpeg/lib/libswresample.dylib"},
			{type = "copy_exact", src = prefix .. "/ffmpeg/lib/libavcodec.dylib", dst = "${bin_dir}/libavcodec.dylib", flags = "-Lf"},
			{type = "copy_exact", src = prefix .. "/ffmpeg/lib/libavformat.dylib", dst = "${bin_dir}/libavformat.dylib", flags = "-Lf"},
			{type = "copy_exact", src = prefix .. "/ffmpeg/lib/libavutil.dylib", dst = "${bin_dir}/libavutil.dylib", flags = "-Lf"},
			{type = "copy_exact", src = prefix .. "/ffmpeg/lib/libswscale.dylib", dst = "${bin_dir}/libswscale.dylib", flags = "-Lf"},
			{type = "copy_exact", src = prefix .. "/ffmpeg/lib/libswresample.dylib", dst = "${bin_dir}/libswresample.dylib", flags = "-Lf"},
		},
	})
end

return FFmpegSourceSpec
