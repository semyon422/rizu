local LegacyBinding = {}

---@param root table
---@param path string[]
---@return table parent
---@return string key
function LegacyBinding.resolve(root, path)
	assert(#path > 0, "legacy setting path must not be empty")
	local parent = root
	for index = 1, #path - 1 do
		parent = assert(parent[path[index]], "unknown legacy setting path: " .. table.concat(path, "."))
		assert(type(parent) == "table", "legacy setting parent must be a table: " .. table.concat(path, "."))
	end
	return parent, path[#path]
end

---@param path string[]
---@return string key
function LegacyBinding.key(path)
	return table.concat(path, ".")
end

return LegacyBinding
