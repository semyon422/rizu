if arg[2] == "cli" then
	table.remove(arg, 1)
	table.remove(arg, 1)
	dofile("sea/app/cli.lua")
	return
end

require("mime")
require("ltn12")
require("enet")
require("socket")

if arg[2] == "debug" then
    require("lldebugger").start()
end

require("pkg_config")

require("pprint").export()
require("coext").export()

local luacov_runner
if arg[2] == "test" then
	local ok, err = pcall(require, "luacov.runner")
	if ok then
		luacov_runner = err
		luacov_runner.init()
	end
end

local deco = require("deco")
deco.read_file = love.filesystem.read
deco.blacklist = {
	"3rd-deps",
	"tree",
	"aqua/byte.lua",
	-- "sphere/views",
}

local reqprof = require("reqprof")
if love.filesystem.getInfo("reqprof", "file") then
	deco.add(reqprof.ProfileDecorator())
	print("enabled reqprof.ProfileDecorator")
end

local typecheck = require("typecheck")
if love.filesystem.getInfo("typecheck", "file") then
	typecheck.strict = true
	deco.add(require("typecheck.TypeDecorator")())
	deco.add(require("typecheck.ClassDecorator")())
	print("enabled typecheck.TypeDecorator")
	print("enabled typecheck.ClassDecorator")
end

deco.replace_loader()

local ffi = require("ffi")

local source = love.filesystem.getSource()
local sourceBase = love.filesystem.getSourceBaseDirectory()

local root
if source:find("^.+%.love$") then
	print("starting from .love file directly")
	root = sourceBase
else
	print("starting from current directory")
	root = source
end

if jit.os == "Windows" then
	local winapi = require("winapi")
	winapi.putenv("PATH", ("%s;%s"):format(winapi.getenv("PATH"), root .. "/bin/win64"))
	winapi.chdir(root)
elseif jit.os == "Linux" then
	local ldlp = os.getenv("LD_LIBRARY_PATH")
	if not ldlp or not ldlp:find("bin/linux64") then
		ffi.cdef("int setenv(const char *name, const char *value, int overwrite);")
		ffi.C.setenv("LD_LIBRARY_PATH", (ldlp or "") .. ":" .. root .. "/bin/linux64", true)
		os.execute(("%q %q &"):format(arg[-2], arg[1]))
		return os.exit()
	end
	ffi.cdef("int chdir(const char *path);")
	ffi.C.chdir(root)
elseif jit.os == "OSX" then
	local ldlp = os.getenv("DYLD_FALLBACK_LIBRARY_PATH")
	if not ldlp or not ldlp:find("bin/mac64") then
		ffi.cdef("int setenv(const char *name, const char *value, int overwrite);")
		ffi.C.setenv("DYLD_FALLBACK_LIBRARY_PATH", root .. "/bin/mac64", true)
		--os.execute(("%q %q &"):format(arg[-2], arg[1]))
		--return os.exit()
	end
	ffi.cdef("int chdir(const char *path);")
	ffi.C.chdir(root)
end

love.errorhandler = require("errhand")

love.filesystem.unmountCommonPath("appsavedir")
love.filesystem.unmountFullPath(root)
assert(love.filesystem.mountFullPath(root, "/", "readwrite", false))

require("preload")

pcall(require, "luamidi")

setmetatable(_G, {__newindex = function(a, b, c)
	print("__newindex", a, b, c, debug.traceback())
	rawset(a, b, c)
end})

local current_loop = love.run()
function love.run()
	return function()
		return current_loop()
	end
end

if arg[2] == "test" then
	local stbl = require("stbl")
	local utf8validate = require("utf8validate")
	local typecheck = require("typecheck")

	function love.errorhandler(msg)
		if type(msg) ~= "string" then
			if type(msg) ~= "table" then
				msg = tostring(msg)
			else
				local _ = false
				_, msg = pcall(stbl.encode, msg)
			end
		end
		local message = utf8validate(msg)
		local trace = debug.traceback()

		message = typecheck.fix_traceback(message)
		trace = typecheck.fix_traceback(trace)

		print(message .. "\n" .. trace)
		os.exit()
		return function() end
	end

	local Testing = require("testing.Testing")
	local BaseTestingIO = require("testing.BaseTestingIO")

	local tio = BaseTestingIO()
	tio.blacklist = {
		".git",
		"3rd-deps",
		"tree",
		"userdata",
		"storages",
		"build/deps/",
	}

	local testing = Testing(tio)

	local file_pattern, method_pattern = arg[3], arg[4]
	testing:test(file_pattern, method_pattern)

	if luacov_runner then
		debug.sethook(nil)
		luacov_runner.save_stats()
		require("luacov.reporter.lcov").report()
	end

	os.exit()
end

local delay = require("delay")
delay.set_timer(love.timer.getTime)

---@type sphere.GameController?
local game

local thread = require("thread")
thread.setInitFunc(function(packageLoader)
	print("thread init")
	require("preload")
	if not packageLoader then
		return
	end
	local PackageLoader = require("rizu.pkg.PackageLoader")
	local PackageRequire = require("rizu.pkg.PackageRequire")
	setmetatable(packageLoader, PackageLoader)
	---@cast packageLoader rizu.PackageLoader
	local packageRequire = PackageRequire()
	local pkgs = packageLoader:getPackagesByType("require")
	packageRequire:require(pkgs)
end, function()
	return {game and game.packageManager.loader}
end)

thread.coro(function()
	local UpdateController = require("rizu.update.UpdateController")
	local updateController = UpdateController()
	local needRestart = updateController:updateAsync()
	if needRestart then
		thread.unload()
		thread.waitAsync()
		return love.event.quit("restart")
	end
	thread.stopThreads()

	local GameController = require("sphere.controllers.GameController")
	game = GameController()

	game:load()

	local loop = require("rizu.loop.Loop")
	loop:init()
	current_loop = loop:run()
	loop:add(game)
end)()
