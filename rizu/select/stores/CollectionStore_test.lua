local CollectionStore = require("rizu.select.stores.CollectionStore")

local test = {}

---@return rizu.library.Collections.TreeNode
local function makeTree()
	local root = {
		count = 1,
		selected = 1,
		depth = 0,
		path = nil,
		location_id = nil,
		name = "/",
		indexes = {},
		items = {},
	}
	local child = {
		count = 1,
		selected = 1,
		depth = 1,
		path = "packs",
		location_id = nil,
		name = "packs",
		indexes = {},
		items = {root},
	}
	root.indexes.packs = 2
	root.items = {root, child}
	return root
end

---@param t testing.T
function test.nil_path_selects_root(t)
	local library = {
		getCollectionTree = function()
			return makeTree()
		end,
	}
	local store = CollectionStore(library)

	store:load(false)
	store:setPath("packs")
	t:eq(store.tree.selected, 2)

	store:setPath(nil, nil)
	t:eq(store.tree, store.root_tree)
	t:eq(store.tree.selected, 1)
end

return test
