local ListView = require("sphere.views.ListView")
local just = require("just")
local TextCellImView = require("ui.imviews.TextCellImView")

local CollectionListView = ListView()

CollectionListView.rows = 11

function CollectionListView:reloadItems()
	local collectionStore = self.game.collectionSelector.store
	if not self.isSubscribed then
		collectionStore:onChanged(self)
		self.isSubscribed = true
		self.items = collectionStore.tree.items
		self.refreshNeeded = true
	end

	if self.refreshNeeded then
		self.stateCounter = (self.stateCounter or 0) + 1
		self.refreshNeeded = false
	end
end

function CollectionListView:receive()
	local collectionStore = self.game.collectionSelector.store
	self.items = collectionStore.tree.items
	self.refreshNeeded = true
end

---@return number
function CollectionListView:getItemIndex()
	local collectionStore = self.game.collectionSelector.store
	return collectionStore.tree.selected
end

---@param count number
function CollectionListView:scroll(count)
	self.game.collectionSelector:scrollCollection(count)
end

---@param ... any?
function CollectionListView:draw(...)
	ListView.draw(self, ...)

	local collectionStore = self.game.collectionSelector.store

	local kp = just.keypressed
	if kp("up") or kp("left") then self:scroll(-1)
	elseif kp("down") or kp("right") then self:scroll(1)
	elseif kp("pageup") then self:scroll(-10)
	elseif kp("pagedown") then self:scroll(10)
	elseif kp("home") then self:scroll(-math.huge)
	elseif kp("end") then self:scroll(math.huge)
	elseif kp("return") then
		collectionStore:enter()
		self.game.collectionSelector:scrollCollection(0, nil, true)
	end
end

---@param i number
---@param w number
---@param h number
function CollectionListView:drawItem(i, w, h)
	local collectionStore = self.game.collectionSelector.store
	local tree = collectionStore.tree
	local item = self:get(i)

	local name = item.name
	if item.depth == tree.depth and item.depth ~= 0 then
		name = "."
	elseif item.depth == tree.depth - 1 then
		name = ".."
	end

	local items = ""
	if #item.items > 1 then
		items = #item.items
	end

	TextCellImView(72, h, "right", items, item.count ~= 0 and item.count or "", true)
	just.sameline()
	just.indent(44)
	TextCellImView(math.huge, h, "left", "", name)
end

return CollectionListView
