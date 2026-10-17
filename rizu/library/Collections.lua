local class = require("class")
local path_util = require("path_util")
local string_util = require("string_util")

---@class rizu.library.Collections.TreeNode
---@field count integer
---@field selected 1|2
---@field depth integer
---@field path string?
---@field location_id integer?
---@field name string
---@field indexes {[string]: integer}
---@field items rizu.library.Collections.TreeNode[]

---@class rizu.library.Collections
---@operator call: rizu.library.Collections
local Collections = class()

---@param chartfilesRepo rizu.library.ChartfilesRepo
---@param locationsRepo rizu.library.LocationsRepo
function Collections:new(chartfilesRepo, locationsRepo)
	self.chartfilesRepo = chartfilesRepo
	self.locationsRepo = locationsRepo
end

---@param dir string
---@param tree rizu.library.Collections.TreeNode
---@param location_id integer?
local function process_chartfile_set(dir, tree, location_id)
	local t = tree
	t.count = t.count + 1
	if dir then
		---@type string[]
		local tpath = {}
		local depth = tree.depth
		for i, k in ipairs(string_util.split(dir, "/")) do
			depth = depth + 1
			tpath[i] = k
			local index = t.indexes[k]
			local item = t.items[index]
			if not item then
				item = {
					count = 0,
					selected = 2,
					depth = depth,
					path = path_util.join(unpack(tpath)),
					location_id = location_id,
					name = k,
					indexes = {},
					items = {t},
				}
				index = #t.items + 1
				t.indexes[k] = index
				t.items[index] = item
			end
			t = item
			t.count = t.count + 1
		end
	end
end

---@param locations_in_collections boolean
---@return rizu.library.Collections.TreeNode
function Collections:getTree(locations_in_collections)
	---@type rizu.library.Collections.TreeNode
	local tree = {
		count = 0,
		selected = 1,
		depth = 0,
		path = nil,
		location_id = nil,
		name = "/",
		indexes = {},
		items = {},
	}
	tree.items[1] = tree

	local chartfilesRepo = self.chartfilesRepo
	local locationsRepo = self.locationsRepo
	if not locations_in_collections then
		for _, chartfile_set in ipairs(chartfilesRepo:selectChartfileSets()) do
			process_chartfile_set(chartfile_set.dir, tree, nil)
		end
	else
		local locations = locationsRepo:selectLocations()
		for _, location in ipairs(locations) do
			---@type rizu.library.Collections.TreeNode
			local subtree = {
				count = 0,
				selected = 2,
				depth = 1,
				path = nil,
				location_id = location.id,
				name = location.name,
				indexes = {},
				items = {tree},
			}
			table.insert(tree.items, subtree)
			for _, chartfile_set in ipairs(chartfilesRepo:selectChartfileSetsAtLocation(location.id)) do
				process_chartfile_set(chartfile_set.dir, subtree, location.id)
			end
		end
	end

	return tree
end

return Collections
