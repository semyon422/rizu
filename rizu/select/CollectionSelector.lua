local class = require("class")
local Observable = require("Observable")
local CollectionStore = require("rizu.select.stores.CollectionStore")

---@class rizu.select.CollectionSelector
---@operator call: rizu.select.CollectionSelector
local CollectionSelector = class()

---@param configModel sphere.ConfigModel
---@param library rizu.library.Library
function CollectionSelector:new(configModel, library)
	self.configModel = configModel
	self.library = library
	self.store = CollectionStore(library)
	self.observable = Observable()
end

---@param observer rizu.select.CollectionSelectorEventObserver|rizu.select.CollectionSelectorEventReceiver
---@return util.Observer
function CollectionSelector:onChanged(observer)
	---@cast observer util.Observer|util.EventReceiver
	return self.observable:add(observer)
end

---@param observer util.Observer
---@return util.Observer?
function CollectionSelector:offChanged(observer)
	return self.observable:remove(observer)
end

---@param event rizu.select.CollectionSelectorEvent
function CollectionSelector:emitChanged(event)
	self.observable:send(event)
end

function CollectionSelector:load()
	local settings = self.configModel.configs.settings
	local config = self.configModel.configs.select
	self.store:load(settings.select.locations_in_collections)
	self.store:setPath(config.collection, config.location_id)
end

---@param path string?
---@param location_id integer?
function CollectionSelector:selectCollection(path, location_id)
	local old_item = self:getSelectedItem()
	self.store:setPath(path, location_id)

	local item = self:getSelectedItem()
	local config = self.configModel.configs.select
	config.collection = item and item.path
	config.location_id = item and item.location_id

	self:emitChanged({
		type = "collection_selection_changed",
		item = item,
		path_changed = not old_item or old_item.path ~= (item and item.path)
	})
end

---@param enabled boolean
function CollectionSelector:setLocationsInCollections(enabled)
	local settings = self.configModel.configs.settings
	local config = self.configModel.configs.select
	local old_item = self:getSelectedItem()

	settings.select.locations_in_collections = enabled
	self.store:load(enabled)
	self.store:setPath(config.collection, config.location_id)

	local item = self:getSelectedItem()
	config.collection = item and item.path
	config.location_id = item and item.location_id

	self:emitChanged({
		type = "collection_selection_changed",
		item = item,
		path_changed = not old_item or old_item.path ~= (item and item.path)
	})
end

---@param direction integer?
---@param destination integer?
---@param force boolean?
function CollectionSelector:scrollCollection(direction, destination, force)
	local items = self.store.tree.items
	local selected = self.store.tree.selected

	destination = math.min(math.max(destination or selected + direction, 1), #items)
	if not items[destination] or not force and selected == destination then
		return
	end

	local old_item = items[selected]
	self.store.tree.selected = destination

	local item = items[destination]
	local config = self.configModel.configs.select
	config.collection = item.path
	config.location_id = item.location_id

	self:emitChanged({
		type = "collection_selection_changed",
		item = item,
		path_changed = not old_item or old_item.path ~= item.path
	})
end

---@return table?
function CollectionSelector:getSelectedItem()
	return self.store.tree.items[self.store.tree.selected]
end

return CollectionSelector
