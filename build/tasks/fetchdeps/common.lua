local Common = {}

function Common.processFFmpeg(env)
	local ctx = env.ctx
	local target = env.target
	local deps = env.deps
	local platform_bin = env.platform_bin

	local ffmpeg = deps.ffmpeg[target]
	if not ffmpeg then
		return
	end

	local dest = "build/downloads/" .. ffmpeg.archive
	local extract_to = "build/deps/" .. ffmpeg.dir
	local extracted = ctx.fs:getInfo(extract_to)
	if not extracted then
		if not ctx.fs:getInfo(dest) or ctx.fs:getInfo(dest).size == 0 then
			ctx.downloader:download(ffmpeg.url, dest)
		end
		ctx.fs:createDirectory(extract_to)
		if ffmpeg.archive:match("%.tar%.xz$") then
			ctx.shell:execute(string.format("tar -xf %q -C %q --strip-components=1", dest, extract_to))
		else
			local tmp = extract_to .. "-tmp"
			ctx.fs:createDirectory(tmp)
			ctx.shell:execute(string.format("unzip -o %q -d %q", dest, tmp))
			ctx.shell:execute(string.format("cp -r %s/*/* %s/", tmp, extract_to))
			ctx.fs:remove(tmp)
		end
	end

	if target == "linux" then
		ctx.shell:execute(string.format("find %s/lib -maxdepth 1 -name \"*.so.[0-9]*\" ! -name \"*.so.[0-9]*.*[0-9]*\" -exec cp -Lf {} %s \\;", extract_to, platform_bin))
		ctx.shell:execute(string.format("rm -f %q %q %q %q %q %q %q", platform_bin .. "/libavcodec.so", platform_bin .. "/libavdevice.so", platform_bin .. "/libavfilter.so", platform_bin .. "/libavformat.so", platform_bin .. "/libavutil.so", platform_bin .. "/libswresample.so", platform_bin .. "/libswscale.so"))
	elseif target == "windows" then
		ctx.shell:execute(string.format("cp -r %s/bin/*.dll %s/", extract_to, platform_bin))
	end
end

function Common.processGenericZipDeps(env)
	local ctx = env.ctx
	local target = env.target
	local deps = env.deps
	local platform_bin = env.platform_bin
	local generic_deps = {"bass", "bassmix", "bass_fx", "bassopus", "discord_rpc"}

	for _, dep_name in ipairs(generic_deps) do
		local config = deps[dep_name] and deps[dep_name][target]
		if config then
			local dest = "build/downloads/" .. config.archive
			local extract_to = "build/deps/" .. dep_name .. "_" .. target
			local have_extract = ctx.fs:getInfo(extract_to)
			local info = ctx.fs:getInfo(dest)
			if info and info.size < 1024 and not have_extract then
				print("Removing corrupted dependency archive: " .. dest)
				ctx.fs:remove(dest)
				info = nil
			end

			if not have_extract then
				if not info or info.size == 0 then
					ctx.downloader:download(config.url, dest)
				end
				ctx.fs:createDirectory(extract_to)
				ctx.shell:execute(string.format("unzip -o %q -d %q", dest, extract_to))
			end

			local ext = target == "windows" and "dll" or (target == "macos" and "dylib" or "so")
			if dep_name:match("^bass") then
				if target == "windows" then
					ctx.shell:execute(string.format("cp %s/x64/*.dll %s/ 2>/dev/null || cp %s/*.dll %s/ 2>/dev/null", extract_to, platform_bin, extract_to, platform_bin))
				elseif target == "linux" then
					ctx.shell:execute(string.format("cp %s/libs/x86_64/*.so %s/ 2>/dev/null || cp %s/*.so %s/ 2>/dev/null", extract_to, platform_bin, extract_to, platform_bin))
				else
					ctx.shell:execute(string.format("find %s -name \"*.dylib\" -exec cp {} %s/ \\;", extract_to, platform_bin))
				end
			else
				ctx.shell:execute(string.format("find %s -name \"*.%s*\" -exec cp {} %s/ \\;", extract_to, ext, platform_bin))
			end
		end
	end
end

function Common.processGitDeps(env)
	local ctx = env.ctx
	local deps = env.deps
	local git_deps = {"minacalc", "luamidi"}

	for _, dep_name in ipairs(git_deps) do
		local config = deps[dep_name]
		local dep_dir = "build/deps/" .. dep_name
		if not ctx.fs:getInfo(dep_dir) then
			print("Cloning " .. dep_name .. "...")
			ctx.shell:execute(string.format("git clone %s %s", config.url, dep_dir))
		end
		if dep_name == "luamidi" and not ctx.fs:getInfo(dep_dir .. "/rtmidi/RtMidi.h") then
			print("Initializing luamidi submodules...")
			ctx.shell:execute(string.format("git -C %s submodule update --init --recursive", dep_dir))
		end
	end
end

function Common.processPrebuiltBins(env)
	local ctx = env.ctx
	local target = env.target
	local deps = env.deps
	local platform_bin = env.platform_bin
	local prebuilt = deps.prebuilt_bins and deps.prebuilt_bins[target] or {}

	for _, item in ipairs(prebuilt) do
		local dest = "build/downloads/prebuilt/" .. target .. "/" .. item.name
		local bin_path = platform_bin .. "/" .. item.name
		local local_path = item.local_path
		local has_local = local_path and ctx.fs:getInfo(local_path)
		local has_dest = ctx.fs:getInfo(dest) and ctx.fs:getInfo(dest).size > 0
		local has_bin = ctx.fs:getInfo(bin_path)

		if has_local then
			ctx.shell:execute(string.format("cp -f %q %q", local_path, bin_path))
			if not has_dest then
				ctx.shell:execute(string.format("cp -f %q %q", local_path, dest))
			end
			goto continue_prebuilt
		end

		if has_dest then
			ctx.shell:execute(string.format("cp -f %q %q", dest, bin_path))
			goto continue_prebuilt
		end

		if has_bin then
			goto continue_prebuilt
		end

		if item.url then
			ctx.downloader:download(item.url, dest)
			ctx.shell:execute(string.format("cp -f %q %q", dest, bin_path))
		else
			error("Prebuilt dependency is missing and has no download URL: " .. item.name)
		end

		::continue_prebuilt::
	end
end

function Common.processSevenZip(env)
	local ctx = env.ctx
	local deps = env.deps
	local s7 = deps.sevenzip
	local s7_dest = "build/downloads/" .. s7.archive
	local s7_extract = "build/deps/" .. s7.dir
	if not ctx.fs:getInfo(s7_dest) then
		ctx.downloader:download(s7.url, s7_dest)
	end
	ctx.fs:createDirectory(s7_extract)
	ctx.shell:execute(string.format("7z x -y %q -o%q", s7_dest, s7_extract))
end

function Common.processLoveArtifacts(env)
	local ctx = env.ctx
	local deps = env.deps
	local platform_bin_map = env.platform_bin_map

	local love_win = deps.love_win
	if love_win then
		local dest = "build/downloads/" .. love_win.archive
		if not ctx.fs:getInfo(dest) then
			ctx.downloader:download(love_win.url, dest)
		end
		local extract_to = "build/deps/love_win"
		ctx.fs:createDirectory(extract_to)
		ctx.shell:execute(string.format("unzip -o %q -d %q", dest, extract_to))
		ctx.shell:execute(string.format("cp -r %s/*/* %s/", extract_to, platform_bin_map.windows))
	end

	local love_linux = deps.love_linux
	if love_linux then
		local dest = "build/downloads/" .. love_linux.archive
		if not ctx.fs:getInfo(dest) then
			ctx.downloader:download(love_linux.url, dest)
		end
		ctx.shell:execute(string.format("cp %s %s/", dest, platform_bin_map.linux))
		ctx.shell:execute(string.format("chmod +x %s/%s", platform_bin_map.linux, love_linux.archive))
	end

	local love_macos = deps.love_macos
	if love_macos then
		local dest = "build/downloads/" .. love_macos.archive
		if not ctx.fs:getInfo(dest) then
			ctx.downloader:download(love_macos.url, dest)
		end
	end
end

function Common.runShared(env)
	Common.processFFmpeg(env)
	Common.processGenericZipDeps(env)
	Common.processGitDeps(env)
	Common.processPrebuiltBins(env)
	Common.processSevenZip(env)
	Common.processLoveArtifacts(env)
end

return Common
