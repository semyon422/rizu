local Common = {}

local GENERIC_DEPS = {"bass", "bassmix", "bass_fx", "bassopus", "discord_rpc"}
local STATUS_GENERIC_DEPS = {"bass", "discord_rpc"}

local function addFFmpeg(target, deps, spec)
	local ffmpeg = deps.ffmpeg[target]
	if not ffmpeg then
		return
	end
	local archive = "${downloads_dir}/" .. ffmpeg.archive
	local extract = "${deps_dir}/" .. ffmpeg.dir
	table.insert(spec.steps, {
		id = "ffmpeg_binary",
		kind = "archive",
		inputs = {archive},
		actions = {
			{type = "download", url = ffmpeg.url, dest = archive},
			{type = "extract", format = ffmpeg.archive:match("%.tar%.xz$") and "tar.xz" or "zip_nested", archive = archive, dest = extract, skip_if_exists = true},
			{type = "shell", stderr_hint = "Shell command failed", command = target == "linux"
				and ("find " .. extract .. "/lib -maxdepth 1 -name \"*.so.[0-9]*\" ! -name \"*.so.[0-9]*.*[0-9]*\" -exec cp -Lf {} ${bin_dir} \\;")
				or ("cp -r " .. extract .. "/bin/*.dll ${bin_dir}/")},
		},
	})
	if target == "linux" then
		table.insert(spec.steps[#spec.steps].actions, {type = "shell", stderr_hint = "Shell command failed", command = "rm -f ${bin_dir}/libavcodec.so ${bin_dir}/libavdevice.so ${bin_dir}/libavfilter.so ${bin_dir}/libavformat.so ${bin_dir}/libavutil.so ${bin_dir}/libswresample.so ${bin_dir}/libswscale.so"})
	end
	table.insert(spec.required_paths, extract)
	table.insert(spec.status_rows, {
		name = "FFmpeg (" .. target .. ")",
		format = "dl_ex",
		download = archive,
		extract = extract,
	})
end

local function addGenericDeps(target, deps, spec)
	for _, dep_name in ipairs(GENERIC_DEPS) do
		local cfg = deps[dep_name] and deps[dep_name][target]
		if cfg then
			local archive = "${downloads_dir}/" .. cfg.archive
			local extract = "${deps_dir}/" .. dep_name .. "_" .. target
			local ext = target == "windows" and "dll" or (target == "macos" and "dylib" or "so")
			local copy_action
			local pre_actions = {}
			if dep_name:match("^bass") then
				if target == "windows" then
					table.insert(pre_actions, {type = "assert_dir", path = extract .. "/x64", message = "Expected x64 directory for " .. dep_name .. " at " .. extract .. "/x64"})
					copy_action = {type = "copy_glob", pattern = extract .. "/x64/*.dll", dst = "${bin_dir}/", flags = "-f"}
				elseif target == "linux" then
					table.insert(pre_actions, {type = "assert_dir", path = extract .. "/libs/x86_64", message = "Expected x86_64 directory for " .. dep_name .. " at " .. extract .. "/libs/x86_64"})
					copy_action = {type = "copy_glob", pattern = extract .. "/libs/x86_64/*.so", dst = "${bin_dir}/", flags = "-f"}
				else
					copy_action = {type = "shell", stderr_hint = "BASS macOS copy failed", command = "find " .. extract .. " -name \"*.dylib\" -exec cp {} ${bin_dir}/ \\;"}
				end
			else
				copy_action = {type = "shell", stderr_hint = "Generic dependency copy failed", command = "find " .. extract .. " -name \"*." .. ext .. "*\" -exec cp {} ${bin_dir}/ \\;"}
			end

			local actions = {
				{type = "download", url = cfg.url, dest = archive},
				{type = "extract", format = "zip", archive = archive, dest = extract, skip_if_exists = true},
			}
			for _, a in ipairs(pre_actions) do
				table.insert(actions, a)
			end
			table.insert(actions, copy_action)

			table.insert(spec.steps, {
				id = "dep_" .. dep_name,
				kind = "archive",
				skip_if_exists_all = {extract},
				actions = actions,
			})
			table.insert(spec.required_paths, extract)
		end
	end

	for _, dep_name in ipairs(STATUS_GENERIC_DEPS) do
		local cfg = deps[dep_name] and deps[dep_name][target]
		if cfg then
			table.insert(spec.status_rows, {
				name = dep_name:upper() .. " (" .. target .. ")",
				format = "dl_ex",
				download = "${downloads_dir}/" .. cfg.archive,
				extract = "${deps_dir}/" .. dep_name .. "_" .. target,
			})
		end
	end
end

local function addGitDeps(spec, deps)
	for _, dep_name in ipairs({"minacalc", "luamidi"}) do
		local cfg = deps[dep_name]
		local dep_dir = "${deps_dir}/" .. dep_name
		table.insert(spec.steps, {
			id = "git_" .. dep_name,
			kind = "git",
			actions = {
				{type = "git_clone", url = cfg.url, dest = dep_dir},
			},
		})
		table.insert(spec.required_paths, dep_dir)
		table.insert(spec.status_rows, {
			name = dep_name:upper() .. " (git)",
			format = "exists",
			path = dep_dir,
		})
	end
	table.insert(spec.steps, {
		id = "git_luamidi_submodule",
		kind = "git",
		actions = {
			{type = "git_submodule", dir = "${deps_dir}/luamidi", marker = "${deps_dir}/luamidi/rtmidi/RtMidi.h"},
		},
	})
	table.insert(spec.required_paths, "${deps_dir}/luamidi/rtmidi/RtMidi.h")
end

local function addSevenZip(spec, deps)
	local s7 = deps.sevenzip
	local dest = "${downloads_dir}/" .. s7.archive
	local extract = "${deps_dir}/" .. s7.dir
	table.insert(spec.steps, {
		id = "sevenzip_sdk",
		kind = "archive",
		actions = {
			{type = "download", url = s7.url, dest = dest},
			{type = "extract", format = "7z", archive = dest, dest = extract},
		},
	})
	table.insert(spec.required_paths, extract)
	table.insert(spec.status_rows, {
		name = "7z SDK",
		format = "dl_ex",
		download = dest,
		extract = extract,
	})
end

local function addLoveArtifacts(spec, deps)
	if deps.love_win then
		table.insert(spec.steps, {
			id = "love_win",
			kind = "archive",
			actions = {
				{type = "download", url = deps.love_win.url, dest = "${downloads_dir}/" .. deps.love_win.archive},
				{type = "ensure_dir", path = "${deps_dir}/love_win"},
				{type = "extract", format = "zip", archive = "${downloads_dir}/" .. deps.love_win.archive, dest = "${deps_dir}/love_win"},
				{type = "shell", stderr_hint = "Shell command failed", command = "cp -r ${deps_dir}/love_win/*/* ${bin_windows}/"},
			},
		})
		table.insert(spec.required_paths, "${deps_dir}/love_win")
	end
	if deps.love_linux then
		table.insert(spec.steps, {
			id = "love_linux",
			kind = "archive",
			actions = {
				{type = "download", url = deps.love_linux.url, dest = "${downloads_dir}/" .. deps.love_linux.archive},
				{type = "copy", src = "${downloads_dir}/" .. deps.love_linux.archive, dst = "${bin_linux}/", flags = "-f"},
				{type = "shell", stderr_hint = "Shell command failed", command = "chmod +x ${bin_linux}/" .. deps.love_linux.archive},
			},
		})
		table.insert(spec.required_paths, "${bin_linux}/" .. deps.love_linux.archive)
	end
	if deps.love_macos then
		table.insert(spec.steps, {
			id = "love_macos",
			kind = "archive",
			actions = {
				{type = "download", url = deps.love_macos.url, dest = "${downloads_dir}/" .. deps.love_macos.archive},
			},
		})
		table.insert(spec.required_paths, "${downloads_dir}/" .. deps.love_macos.archive)
		table.insert(spec.status_rows, {
			name = "macOS Love Zip",
			format = "exists",
			path = "${downloads_dir}/" .. deps.love_macos.archive,
		})
	end
end

function Common.buildShared(target, deps)
	local spec = {
		target = target,
		steps = {},
		required_paths = {},
		status_rows = {},
	}
	addFFmpeg(target, deps, spec)
	addGenericDeps(target, deps, spec)
	addGitDeps(spec, deps)
	addSevenZip(spec, deps)
	addLoveArtifacts(spec, deps)
	return spec
end

return Common
