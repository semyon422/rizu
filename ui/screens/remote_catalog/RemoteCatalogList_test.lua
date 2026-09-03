local RemoteCatalogList = require("ui.screens.remote_catalog.RemoteCatalogList")

local test = {}

---@param t testing.T
function test.resets_scroll_when_items_change(t)
	local list = RemoteCatalogList()
	list:anchorFixed(0, 0, 500, 100)
	list:setItems({
		{id = "1", title = "One"},
		{id = "2", title = "Two"},
		{id = "3", title = "Three"},
	})
	list:scrollTo(50, true)
	list:setItems({{id = "4", title = "Four"}})

	t:eq(list:getItemCount(), 1)
	t:eq(list:getScrollPosition(), 0)
end

---@param t testing.T
function test.selects_clicked_item(t)
	local selected
	local list = RemoteCatalogList(function(item, index)
		selected = {item, index}
	end)
	list:anchorFixed(0, 0, 500, 100)
	list:setItems({{id = "1", title = "One"}, {id = "2", title = "Two"}})
	local screen = require("gui.Screen")()
	screen.root:add(list)
	screen:resize(500, 100)

	list:onMouseClick({button = 1, x = 10, y = 80})
	t:eq(list.selected_index, 2)
	t:eq(selected[1].id, "2")
	t:eq(selected[2], 2)
end

return test
