local path_util = require("path_util")

---Creates a cached module loader scoped to one custom skin directory.
---Modules execute without injected chunk arguments.
---@param fs fs.IFilesystem
---@param directory_path string
---@return fun(name: string): any
local function SkinModuleLoader(fs, directory_path)
	local modules = {} ---@type {[string]: any}
	local loading = {} ---@type {[string]: boolean}
	---@param name string
	---@return any
	local function loadModule(name)
		assert(type(name) == "string" and name:match("^[%w_/-]+$") and name:sub(1, 1) ~= "/",
			"expected a skin-relative module name without the .lua extension")
		if modules[name] ~= nil then return modules[name] end
		assert(not loading[name], "circular skin module dependency: " .. name)
		local path = path_util.join(directory_path, name .. ".lua")
		local source, read_error = fs:read(path)
		assert(source, read_error or ("could not read skin module: " .. path))
		local chunk, load_error = loadstring(source, "@" .. path)
		assert(chunk, load_error)
		loading[name] = true
		local ok, result = pcall(chunk)
		loading[name] = nil
		if not ok then error(result, 0) end
		if result == nil then result = true end
		modules[name] = result
		return result
	end
	return loadModule
end

return SkinModuleLoader
