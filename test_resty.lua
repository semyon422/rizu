local pkg = require("aqua.pkg")

pkg.addc()
pkg.addc("3rd-deps/lib")
pkg.addc("bin/lib")
pkg.addc("tree/lib/lua/5.1")
pkg.add()
pkg.add("3rd-deps/lua")
pkg.add("aqua")
pkg.add("ncdk")
pkg.add("chartbase")
pkg.add("libchart")
pkg.add("tree/share/lua/5.1")

local or_root = os.getenv("OR_ROOT")
if or_root then
	pkg.add(or_root .. "/lualib")
end

pkg.export_lua()

local pprint = require("pprint")
pprint.export()

-- lua-nginx-module bug fix
coroutine.wrap = require("icc.co").wrap

local luacov_runner
local ok, err = pcall(require, "luacov.runner")
if ok then
	luacov_runner = err
	luacov_runner.init()
end

pkg.export_lua()

local Testing = require("testing.Testing")
local BaseTestingIO = require("testing.BaseTestingIO")

local tio = BaseTestingIO()
tio.blacklist = {
	".git",
	"3rd-deps",
	"tree",
	"userdata",
	"build/deps",
	"releases",
	"current",
	"previous",
}

require("testing.FakeLove").install()

local testing = Testing(tio)

-- Parse flags: --json enables structured JSON output
local i = 1
local json_mode = false
while i <= #arg do
	if arg[i] == "--json" then
		json_mode = true
		table.remove(arg, i)
	else
		i = i + 1
	end
end

local file_pattern, method_pattern = arg[1], arg[2]
if json_mode then
	testing:test_json(file_pattern, method_pattern)
else
	testing:test(file_pattern, method_pattern)
end

if luacov_runner then
	debug.sethook(nil)
	luacov_runner.save_stats()
	require("luacov.reporter.lcov").report()
end

os.exit()
