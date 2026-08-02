local Manifest = require("rizu.build.deps.Manifest")

---@class rizu.build.deps.spec.common.FFmpegSpec
local FFmpegSpec = {}

local FFMPEG_ARTIFACTS = {
	linux = {
		{src = "lib/libavcodec.so.63", dst = "libavcodec.so.63"},
		{src = "lib/libavdevice.so.63", dst = "libavdevice.so.63"},
		{src = "lib/libavfilter.so.12", dst = "libavfilter.so.12"},
		{src = "lib/libavformat.so.63", dst = "libavformat.so.63"},
		{src = "lib/libavutil.so.61", dst = "libavutil.so.61"},
		{src = "lib/libswresample.so.7", dst = "libswresample.so.7"},
		{src = "lib/libswscale.so.10", dst = "libswscale.so.10"},
	},
	windows = {
		{src = "bin/avcodec-63.dll", dst = "avcodec-63.dll"},
		{src = "bin/avdevice-63.dll", dst = "avdevice-63.dll"},
		{src = "bin/avfilter-12.dll", dst = "avfilter-12.dll"},
		{src = "bin/avformat-63.dll", dst = "avformat-63.dll"},
		{src = "bin/avutil-61.dll", dst = "avutil-61.dll"},
		{src = "bin/swresample-7.dll", dst = "swresample-7.dll"},
		{src = "bin/swscale-10.dll", dst = "swscale-10.dll"},
	},
}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
function FFmpegSpec.add(target, spec)
	local ffmpeg = Manifest.ffmpeg[target]
	if not ffmpeg then
		return
	end
	local archive = "${downloads_dir}/" .. ffmpeg.archive
	local extract = "${deps_dir}/" .. ffmpeg.dir
	local actions = {
		{type = "download", url = ffmpeg.url, dest = archive},
		{type = "extract", format = ffmpeg.archive:match("%.tar%.xz$") and "tar.xz" or "zip_nested", archive = archive, dest = extract},
	}
	local artifacts = FFMPEG_ARTIFACTS[target] or {}
	local outputs = {}
	for _, item in ipairs(artifacts) do
		local src = extract .. "/" .. item.src
		local dst = "${bin_dir}/" .. item.dst
		table.insert(actions, {type = "assert_file", path = src})
		table.insert(actions, {type = "copy_exact", src = src, dst = dst, flags = "-Lf"})
		table.insert(outputs, dst)
	end

	table.insert(spec.steps, {
		id = "ffmpeg_binary",
		kind = "archive",
		outputs = outputs,
		actions = actions,
	})
end

return FFmpegSpec
