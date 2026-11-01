local PackageLoader = require("rizu.pkg.PackageLoader")

local test = {}

---@param t testing.T
function test.skips_package_with_invalid_json(t)
	local old_love = love ---@type table?
	local old_print = print ---@type function
	local files = {
		["good/pkg.json"] = '{"name": "good"}',
		["bad/pkg.json"] = '{"name": "bad", 5: 1}',
	}
	love = {
		filesystem = {
			getInfo = function(path)
				return files[path] and {type = "file"}
			end,
			read = function(path)
				return files[path]
			end,
		},
	}
	print = function() end

	local loader = PackageLoader()
	local ok, err = pcall(loader.load, loader, {"good", "bad"})

	love = old_love
	print = old_print
	t:assert(ok, err)
	t:assert(loader.packages.good)
	t:assert(not loader.packages.bad)
end

return test
