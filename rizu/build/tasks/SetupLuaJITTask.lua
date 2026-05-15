local ITask = require("rizu.build.ITask")

---@class rizu.build.tasks.SetupLuaJITTask: rizu.build.ITask
---@operator call: rizu.build.tasks.SetupLuaJITTask
---@field deps string[]
local SetupLuaJITTask = ITask + {}

---@param target "linux"|"windows"
function SetupLuaJITTask:new(target)
	self.target = target
	---@type string
	self.name = "setup_luajit_" .. target
	self.deps = {}
end

---@param ctx rizu.build.Context
function SetupLuaJITTask:run(ctx)
	local target = self.target:lower()
	local deps_dir = "build/deps"
	local luajit_dir = deps_dir .. "/LuaJIT"
	local tree_dir = "tree"

	ctx.fs:createDirectory(deps_dir)

	-- 1. Clone
	if not ctx.fs:getInfo(luajit_dir) then
		print("Cloning LuaJIT...")
		ctx.shell:execute("git clone https://github.com/LuaJIT/LuaJIT " .. luajit_dir)
	end

	-- 2. Build
	print("Building LuaJIT for " .. target .. "...")
	if target == "linux" then
		ctx.shell:execute("make -C " .. luajit_dir .. " -j$(nproc)")

		print("Installing LuaJIT to " .. tree_dir .. "...")
		ctx.shell:execute(string.format("make -C %s install DESTDIR=%q PREFIX=", luajit_dir, ctx.fs:getWorkingDirectory() .. "/" .. tree_dir))

		print("Creating luajit symlink...")
		ctx.shell:execute(string.format("ln -sf %s/bin/luajit-* %s/bin/luajit", tree_dir, tree_dir))

	elseif target == "windows" then
		ctx.shell:execute("make -C " .. luajit_dir .. " clean")
		ctx.shell:execute(string.format("make -C %s -j$(nproc) HOST_CC='gcc -m64' CROSS=x86_64-w64-mingw32- TARGET_SYS=Windows", luajit_dir))

		print("Installing Windows LuaJIT files to " .. tree_dir .. "...")
		ctx.fs:createDirectory(tree_dir .. "/lib")
		ctx.fs:createDirectory(tree_dir .. "/bin")

		local src = luajit_dir .. "/src"
		ctx.shell:execute(string.format("cp %s/lua51.dll %s/bin/", src, tree_dir))
		ctx.shell:execute(string.format("cp %s/lua51.dll %s/lib/", src, tree_dir))

		if ctx.fs:getInfo(src .. "/libluajit-5.1.dll.a") then
			ctx.shell:execute(string.format("cp %s/libluajit-5.1.dll.a %s/lib/", src, tree_dir))
		elseif ctx.fs:getInfo(src .. "/libluajit.a") then
			ctx.shell:execute(string.format("cp %s/libluajit.a %s/lib/libluajit-5.1.dll.a", src, tree_dir))
		end
	else
		error("LuaJIT setup not supported for target: " .. target)
	end

	print("LuaJIT setup complete for " .. target)
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function SetupLuaJITTask:getStatus(ctx)
	local target = self.target:lower()
	local bin = target == "linux" and "tree/bin/luajit" or "tree/bin/lua51.dll"
	local res = {}
	table.insert(res, {name = "LuaJIT (" .. target .. ")", value = ctx.fs:getInfo(bin) and "OK" or "MISSING"})
	return res
end

return SetupLuaJITTask
