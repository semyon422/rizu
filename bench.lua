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
pkg.export_lua()

require("testing.FakeLove").install()

local benchmark_path = assert(arg[1], "benchmark path is required")
local benchmark = assert(dofile(benchmark_path))
for name, run in pairs(benchmark) do
	if not name:match("^__") then
		run()
	end
end
