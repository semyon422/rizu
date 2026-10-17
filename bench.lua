require("pkg_config")

require("testing.FakeLove").install()

local benchmark_path = assert(arg[1], "benchmark path is required")
local benchmark = assert(dofile(benchmark_path))
for name, run in pairs(benchmark) do
	if not name:match("^__") then
		run()
	end
end
