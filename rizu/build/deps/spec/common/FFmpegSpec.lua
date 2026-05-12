---@class rizu.build.deps.spec.common.FFmpegSpec
local FFmpegSpec = {}

local FFMPEG_ARTIFACTS = {
	linux = {
		{src = "lib/libavcodec.so.62", dst = "libavcodec.so.62"},
		{src = "lib/libavdevice.so.62", dst = "libavdevice.so.62"},
		{src = "lib/libavfilter.so.11", dst = "libavfilter.so.11"},
		{src = "lib/libavformat.so.62", dst = "libavformat.so.62"},
		{src = "lib/libavutil.so.60", dst = "libavutil.so.60"},
		{src = "lib/libswresample.so.6", dst = "libswresample.so.6"},
		{src = "lib/libswscale.so.9", dst = "libswscale.so.9"},
	},
	windows = {
		{src = "bin/avcodec-62.dll", dst = "avcodec-62.dll"},
		{src = "bin/avdevice-62.dll", dst = "avdevice-62.dll"},
		{src = "bin/avfilter-11.dll", dst = "avfilter-11.dll"},
		{src = "bin/avformat-62.dll", dst = "avformat-62.dll"},
		{src = "bin/avutil-60.dll", dst = "avutil-60.dll"},
		{src = "bin/swresample-6.dll", dst = "swresample-6.dll"},
		{src = "bin/swscale-9.dll", dst = "swscale-9.dll"},
	},
}

---@param target rizu.build.Target
---@param deps rizu.build.deps.Manifest
---@param spec rizu.build.deps.Spec
function FFmpegSpec.add(target, deps, spec)
	local ffmpeg = deps.ffmpeg[target]
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
