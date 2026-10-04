local Resources = require("ui.Resources")
local MouseClickEvent = require("gui.input.events.MouseClickEvent")
local RemoteCatalogList = require("ui.screens.remote_catalog.RemoteCatalogList")
local Screen = require("gui.Screen")

local test = {}

---@param on_select fun(item: rizu.library.RemoteCatalogItem, index: integer)?
---@return ui.screens.remote_catalog.RemoteCatalogList
local function createList(on_select)
	local old_get_font = Resources.getFont
	Resources.getFont = function()
		return {
			getHeight = function() return 16 end,
			getWidth = function(_, text) return #text * 8 end,
		}
	end
	---@type boolean, ui.screens.remote_catalog.RemoteCatalogList
	local ok, list = pcall(function()
		return RemoteCatalogList(on_select)
	end)
	Resources.getFont = old_get_font
	assert(ok, list)
	return list
end

---@param id string
---@param title string
---@return rizu.library.RemoteCatalogItem
local function createItem(id, title)
	return {
		id = id,
		title = title,
		artist = "Artist",
		name = "Chart",
		creator = "Creator",
		mode = 3,
		keys = 4,
		difficulty = 1,
		format = "osu",
		preview_audio_url = "",
	}
end

---@param t testing.T
function test.resets_scroll_when_items_change(t)
	local list = createList()
	local screen = Screen()
	screen.root:add(list):anchorFill(0, 0, 0, 0)
	screen:resize(500, 100)
	list:setItems({
		createItem("1", "One"),
		createItem("2", "Two"),
		createItem("3", "Three"),
	})
	list:scrollTo(50, true)
	t:eq(list:getScrollPosition(), 50)
	list:setItems({createItem("4", "Four")})

	t:eq(list:getItemCount(), 1)
	t:eq(list:getScrollPosition(), 0)
end

---@param t testing.T
function test.selects_clicked_item(t)
	local selected_item ---@type rizu.library.RemoteCatalogItem?
	local selected_index ---@type integer?
	local list = createList(function(item, index)
		selected_item = item
		selected_index = index
	end)
	list:anchorFixed(0, 0, 500, 100)
	list:setItems({createItem("1", "One"), createItem("2", "Two")})
	local screen = Screen()
	screen.root:add(list)
	screen:resize(500, 100)

	local event = MouseClickEvent({control = false, shift = false, alt = false, super = false})
	event.button, event.x, event.y, event.time = 1, 10, 80, 0
	list:onMouseClick(event)
	t:eq(list.selected_index, 2)
	t:eq(assert(selected_item).id, "2")
	t:eq(selected_index, 2)
end

return test
