
---@param name string
---@return {name: string, data: string}
local function read(name)
	local f = assert(io.open("sea/chart/samples/" .. name, "rb"))
	local data = f:read("*a")
	f:close()

	return {
		name = name,
		data = data,
	}
end

---@type {name: string, data: string}[]
local samples = {
	read("chart_1.sph"),
}

return samples
