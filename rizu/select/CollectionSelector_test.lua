local CollectionSelector = require("rizu.select.CollectionSelector")

local test = {}

---@param selected_item rizu.library.Collections.TreeNode
---@return rizu.select.CollectionSelector
local function newSelector(selected_item)
	local selector = CollectionSelector({
		configs = {select = {}},
	}, {}, {})
	selector.store = {
		tree = {
			selected = 1,
			items = {selected_item},
		},
		setPath = function(self, path, location_id)
			self.tree.items[1] = {
				path = path,
				location_id = location_id,
			}
		end,
	}
	return selector
end

---@param t testing.T
function test.location_change_changes_query_scope(t)
	local selector = newSelector({path = nil, location_id = 1})
	local event
	selector:onChanged(function(e)
		event = e
	end)

	selector:selectCollection(nil, 2)

	t:eq(event.query_scope_changed, true)
end

---@param t testing.T
function test.same_path_and_location_preserves_query_scope(t)
	local selector = newSelector({path = "packs", location_id = 1})
	local event
	selector:onChanged(function(e)
		event = e
	end)

	selector:selectCollection("packs", 1)

	t:eq(event.query_scope_changed, false)
end

return test
