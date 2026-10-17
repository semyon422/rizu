local Manifest = require("rizu.build.deps.Manifest")

---@class rizu.build.deps.spec.common.LoveArtifactsSpec
local LoveArtifactsSpec = {}

---@param spec rizu.build.deps.Spec
function LoveArtifactsSpec.add(spec)
	if Manifest.love_win then
		local outer_tmp = "${deps_dir}/love-win-outer-tmp"
		local inner_tmp = "${deps_dir}/love-win-inner-tmp"
		table.insert(spec.steps, {
			id = "love_win",
			kind = "archive",
			outputs = {
				"${bin_windows}/love.exe",
				"${bin_windows}/lovec.exe",
				"${bin_windows}/love.dll",
				"${bin_windows}/lua51.dll",
				"${bin_windows}/SDL3.dll",
				"${bin_windows}/OpenAL32.dll",
			},
			actions = {
				{type = "download", url = Manifest.love_win.url, dest = "${downloads_dir}/" .. Manifest.love_win.archive},
				{type = "extract", format = "zip", archive = "${downloads_dir}/" .. Manifest.love_win.archive, dest = outer_tmp},
				{type = "extract_first_match", format = "zip", pattern = '"' .. outer_tmp .. '"/love-*.zip', dest = inner_tmp},
				{type = "copy", src = inner_tmp .. "/*/*", dst = "${bin_windows}/", flags = "-rf"},
				{type = "remove", path = outer_tmp, recursive = true},
				{type = "remove", path = inner_tmp, recursive = true},
				{type = "assert_file", path = "${bin_windows}/love.exe"},
				{type = "assert_file", path = "${bin_windows}/lovec.exe"},
				{type = "assert_file", path = "${bin_windows}/love.dll"},
				{type = "assert_file", path = "${bin_windows}/lua51.dll"},
				{type = "assert_file", path = "${bin_windows}/SDL3.dll"},
				{type = "assert_file", path = "${bin_windows}/OpenAL32.dll"},
			},
		})
	end

	if Manifest.love_linux then
		table.insert(spec.steps, {
			id = "love_linux",
			kind = "archive",
			outputs = {
				"${bin_linux}/love-linux-X64.AppImage",
			},
			actions = {
				{type = "download", url = Manifest.love_linux.url, dest = "${downloads_dir}/" .. Manifest.love_linux.archive},
				{type = "extract", format = "zip", archive = "${downloads_dir}/" .. Manifest.love_linux.archive, dest = "${bin_linux}/love-nightly-tmp"},
				{type = "move_first_match", pattern = '"${bin_linux}/love-nightly-tmp"/love-*.AppImage', dst = "${bin_linux}/love-linux-X64.AppImage"},
				{type = "remove", path = "${bin_linux}/love-nightly-tmp", recursive = true},
				{type = "assert_file", path = "${bin_linux}/love-linux-X64.AppImage"},
				{type = "set_executable", path = "${bin_linux}/love-linux-X64.AppImage"},
			},
		})
	end

	if Manifest.love_macos then
		table.insert(spec.steps, {
			id = "love_macos",
			kind = "archive",
			actions = {
				{type = "download", url = Manifest.love_macos.url, dest = "${downloads_dir}/" .. Manifest.love_macos.archive},
			},
		})
	end
end

return LoveArtifactsSpec
