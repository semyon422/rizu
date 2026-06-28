local class = require("class")
local string_util = require("string_util")
local table_util = require("table_util")
local Observable = require("Observable")

---@class rizu.select.stores.CollectionStore
---@operator call: rizu.select.stores.CollectionStore
local CollectionStore = class()

---@param library rizu.library.Library
function CollectionStore:new(library)
	self.library = library
	self.observable = Observable()
end

---@param observer rizu.select.CollectionStoreEventObserver|rizu.select.CollectionStoreEventReceiver
---@return util.Observer
function CollectionStore:onChanged(observer)
	---@cast observer util.Observer|util.EventReceiver
	return self.observable:add(observer)
end

---@param observer util.Observer
---@return util.Observer?
function CollectionStore:offChanged(observer)
	return self.observable:remove(observer)
end

---@param event rizu.select.CollectionStoreEvent
function CollectionStore:emitChanged(event)
	self.observable:send(event)
end

function CollectionStore:enter()
	local node = self.tree.items[self.tree.selected]
	if #node.items > 1 then
		self.tree = node
		self:emitChanged({type = "collection_tree_changed", tree = self.tree})
	end
end

---@param locations_in_collections boolean
function CollectionStore:load(locations_in_collections)
	local tree = self.library:getCollectionTree(locations_in_collections)

	self.locations_in_collections = locations_in_collections
	self.root_tree = tree
	self.tree = tree
	self:emitChanged({type = "collection_tree_changed", tree = self.tree})
end

function CollectionStore:setPath(path, location_id)
	self.tree = self.root_tree
	if not path and not location_id then
		self.tree.selected = 1
		self:emitChanged({type = "collection_tree_changed", tree = self.tree})
		return
	end

	if self.locations_in_collections then
		self:setPathLic(path, location_id)
	else
		self:setPathP(path)
	end
	self:emitChanged({type = "collection_tree_changed", tree = self.tree})
end

function CollectionStore:setPathLic(path, location_id)
	local tree = self.tree

	if not location_id then
		return
	end

	local index = table_util.indexof(tree.items, location_id, function(node)
		return node.location_id
	end)
	tree.selected = index or 1

	if not path then
		return
	end

	self.tree = tree.items[tree.selected]

	self:setPathP(path)
end

function CollectionStore:setPathP(path)
	if not path then
		return
	end

	local tree = self.tree

	local keys = string_util.split(path, "/")
	for i = 1, #keys do
		local index = tree.indexes[keys[i]]
		if index then
			tree.selected = index
			if i < #keys then
				tree = tree.items[index]
				self.tree = tree
			end
		else
			return
		end
	end
end

return CollectionStore
