local LoveArtifactsSpec = {}

function LoveArtifactsSpec.add(deps, spec)
	if deps.love_win then
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
				{type = "download", url = deps.love_win.url, dest = "${downloads_dir}/" .. deps.love_win.archive},
				{type = "extract", format = "zip", archive = "${downloads_dir}/" .. deps.love_win.archive, dest = "${bin_windows}-outer-tmp"},
				{type = "extract_first_match", format = "zip", pattern = '"${bin_windows}-outer-tmp"/love-*.zip', dest = "${bin_windows}-inner-tmp"},
				{type = "copy", src = "${bin_windows}-inner-tmp/*/*", dst = "${bin_windows}/", flags = "-rf"},
				{type = "remove", path = "${bin_windows}-outer-tmp", recursive = true},
				{type = "remove", path = "${bin_windows}-inner-tmp", recursive = true},
				{type = "assert_file", path = "${bin_windows}/love.exe"},
				{type = "assert_file", path = "${bin_windows}/lovec.exe"},
				{type = "assert_file", path = "${bin_windows}/love.dll"},
				{type = "assert_file", path = "${bin_windows}/lua51.dll"},
				{type = "assert_file", path = "${bin_windows}/SDL3.dll"},
				{type = "assert_file", path = "${bin_windows}/OpenAL32.dll"},
			},
		})
	end

	if deps.love_linux then
		table.insert(spec.steps, {
			id = "love_linux",
			kind = "archive",
			outputs = {
				"${bin_linux}/love-linux-X64.AppImage",
			},
			actions = {
				{type = "download", url = deps.love_linux.url, dest = "${downloads_dir}/" .. deps.love_linux.archive},
				{type = "extract", format = "zip", archive = "${downloads_dir}/" .. deps.love_linux.archive, dest = "${bin_linux}/love-nightly-tmp"},
				{type = "move_first_match", pattern = '"${bin_linux}/love-nightly-tmp"/love-*.AppImage', dst = "${bin_linux}/love-linux-X64.AppImage"},
				{type = "remove", path = "${bin_linux}/love-nightly-tmp", recursive = true},
				{type = "assert_file", path = "${bin_linux}/love-linux-X64.AppImage"},
				{type = "set_executable", path = "${bin_linux}/love-linux-X64.AppImage"},
			},
		})
	end

	if deps.love_macos then
		table.insert(spec.steps, {
			id = "love_macos",
			kind = "archive",
			actions = {
				{type = "download", url = deps.love_macos.url, dest = "${downloads_dir}/" .. deps.love_macos.archive},
			},
		})
	end
end

return LoveArtifactsSpec
