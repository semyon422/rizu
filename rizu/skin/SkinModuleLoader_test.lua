local FakeFilesystem = require("fs.FakeFilesystem")
local SkinModuleLoader = require("rizu.skin.SkinModuleLoader")

local test = {}

---@param t testing.T
function test.skin_local_dependencies_are_cached_and_isolated(t)
	local fs = FakeFilesystem()
	fs:createDirectory("skins/one")
	fs:createDirectory("skins/two")
	fs:write("skins/one/Font.lua", "return {}")
	fs:write("skins/two/Font.lua", "return {}")
	fs:write("skins/one/Gauge.lua", 'return function(context) return context:loadModule("Font") end')
	local one = SkinModuleLoader(fs, "skins/one")
	local two = SkinModuleLoader(fs, "skins/two")
	local SkinLoadContext = require("rizu.skin.SkinLoadContext")
	local context = SkinLoadContext({module_loader = one})
	t:eq(one("Gauge")(context), one("Font"))
	t:assert(one("Font") ~= two("Font"))
	t:assert(not pcall(one, "../Font"))
	t:assert(not pcall(one, "Missing"))
end

---@param t testing.T
function test.failed_modules_can_be_retried(t)
	local fs = FakeFilesystem()
	fs:createDirectory("skin")
	fs:write("skin/Module.lua", 'error("failed module")')
	local loadModule = SkinModuleLoader(fs, "skin")
	t:assert(not pcall(loadModule, "Module"))
	fs:write("skin/Module.lua", "return 42")
	t:eq(loadModule("Module"), 42)
end

return test
