local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local Label = require("ui.views.Label")
local Panel = require("ui.views.Panel")
local View = require("gui.View")

---@class ui.screens.locations.LocationRow : gui.View
---@operator call: ui.screens.locations.LocationRow
local LocationRow = View + {}

---@param location rizu.library.Location
---@param width number
---@param on_update_cache fun(location: rizu.library.Location)
---@param on_edit fun(location: rizu.library.Location)
---@param on_delete fun(location: rizu.library.Location)
function LocationRow:new(location, width, on_update_cache, on_edit, on_delete)
	View.new(self)
	self:setSize(width, 100)
	self:add(Panel({color = Colors.panel, line_color = Colors.outline})):anchorFill(0, 0, 0, 0)

	local name = self:add(Label({font_name = "bold", font_size = 24, text = location.name}))
	name:setPosition(24, 20):setSize(width - 540, 30)
	local path = self:add(Label({font_name = "regular", font_size = 16, text = location.path, color = Colors.muted}))
	path:setPosition(24, 58):setSize(width - 540, 24)

	local update_cache = self:add(Button("Update cache", function() on_update_cache(location) end, {
		variant = "primary", shape = "capsule", font_name = "medium", font_size = 16,
	}))
	local update_offset = location.is_internal and -24 or -284
	update_cache:setSize(150, 40):setAlignment(1, 0.5):setOffset(update_offset, 0)
	if location.is_internal then
		return
	end

	local edit = self:add(Button("Edit", function() on_edit(location) end, {
		variant = "secondary", shape = "capsule", font_name = "medium", font_size = 16,
	}))
	edit:setSize(110, 40):setAlignment(1, 0.5):setOffset(-154, 0)
	local delete = self:add(Button("Delete", function() on_delete(location) end, {
		variant = "danger", shape = "capsule", font_name = "medium", font_size = 16,
	}))
	delete:setSize(110, 40):setAlignment(1, 0.5):setOffset(-24, 0)
end

return LocationRow
