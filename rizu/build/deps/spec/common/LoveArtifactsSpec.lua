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
				"${bin_windows}/SDL2.dll",
				"${bin_windows}/OpenAL32.dll",
				"${bin_windows}/mpg123.dll",
			},
			actions = {
				{type = "download", url = deps.love_win.url, dest = "${downloads_dir}/" .. deps.love_win.archive},
				{type = "extract", format = "zip_nested", archive = "${downloads_dir}/" .. deps.love_win.archive, dest = "${bin_windows}"},
				{type = "assert_file", path = "${bin_windows}/love.exe"},
				{type = "assert_file", path = "${bin_windows}/lovec.exe"},
				{type = "assert_file", path = "${bin_windows}/love.dll"},
				{type = "assert_file", path = "${bin_windows}/lua51.dll"},
				{type = "assert_file", path = "${bin_windows}/SDL2.dll"},
				{type = "assert_file", path = "${bin_windows}/OpenAL32.dll"},
				{type = "assert_file", path = "${bin_windows}/mpg123.dll"},
			},
		})
	end

	if deps.love_linux then
		table.insert(spec.steps, {
			id = "love_linux",
			kind = "archive",
			actions = {
				{type = "download", url = deps.love_linux.url, dest = "${downloads_dir}/" .. deps.love_linux.archive},
				{type = "copy", src = "${downloads_dir}/" .. deps.love_linux.archive, dst = "${bin_linux}/", flags = "-f"},
				{type = "set_executable", path = "${bin_linux}/" .. deps.love_linux.archive},
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
