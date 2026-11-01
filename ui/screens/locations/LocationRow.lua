local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local Label = require("ui.views.Label")
local Panel = require("ui.views.Panel")
local View = require("gui.View")

---@class ui.screens.locations.LocationRow : gui.View
---@operator call: ui.screens.locations.LocationRow
---@field location rizu.api.Location
---@field ui ui.UserInterface
---@field path ui.views.Label
---@field update_cache ui.views.Button?
---@field scan ("running"|"queued"|false)?
local LocationRow = View + {}

---@param location rizu.api.Location
---@param width number
---@param ui ui.UserInterface
---@param on_update_cache fun(location: rizu.api.Location)
---@param on_edit fun(location: rizu.api.Location)
---@param on_delete fun(location: rizu.api.Location)
function LocationRow:new(location, width, ui, on_update_cache, on_edit, on_delete)
	View.new(self)
	self.location = location
	self.ui = ui
	self:setSize(width, 100)
	self:add(Panel({color = Colors.panel, line_color = Colors.outline})):anchorFill(0, 0, 0, 0)

	local errored = ui.api.library:getLocationInfo(location).status == "errored"
	local name = self:add(Label({
		font_name = "bold", font_size = 24, text = location.name, color = errored and Colors.danger or nil,
	}))
	name:setPosition(24, 20):setSize(width - 540, 30)
	-- A remote location is known by where its charts come from, not by the folder they are downloaded to.
	local path = self:add(Label({
		font_name = "regular", font_size = 16, text = location.url or location.path, color = Colors.muted,
	}))
	path:setPosition(24, 58):setSize(width - 540, 24)
	self.path = path

	local delete_button = {variant = "danger", shape = "capsule", font_name = "medium", font_size = 16}
	if location.url then
		-- Its charts are listed by the catalog: there is nothing to scan and no folder to choose.
		local delete = self:add(Button(ui.localization:get("locations.delete"), function() on_delete(location) end, delete_button))
		delete:setSize(110, 40):setAlignment(1, 0.5):setOffset(-24, 0)
		return
	end

	local update_cache = self:add(Button(ui.localization:get("locations.update_cache"), function() on_update_cache(location) end, {
		variant = "primary", shape = "capsule", font_name = "medium", font_size = 16,
	}))
	local update_offset = location.is_internal and -24 or -284
	self.update_cache = update_cache
	update_cache:setSize(150, 40):setAlignment(1, 0.5):setOffset(update_offset, 0)
	if location.is_internal then
		return
	end

	local edit = self:add(Button(ui.localization:get("locations.edit"), function() on_edit(location) end, {
		variant = "secondary", shape = "capsule", font_name = "medium", font_size = 16,
	}))
	edit:setSize(110, 40):setAlignment(1, 0.5):setOffset(-154, 0)
	local delete = self:add(Button(ui.localization:get("locations.delete"), function() on_delete(location) end, delete_button))
	delete:setSize(110, 40):setAlignment(1, 0.5):setOffset(-24, 0)
end

---A running scan turns the button into Stop and a queued one into Cancel.
---@param status rizu.api.CacheStatus
---@param scan "running"|"queued"|nil The scan of this location, see rizu.api.Library:getLocationScan().
function LocationRow:setScan(status, scan)
	local button = self.update_cache
	if not button then return end
	local localization = self.ui.localization
	scan = scan or false
	if scan ~= self.scan then
		self.scan = scan
		button.text = localization:get(scan == "running" and "locations.stop_update"
			or scan == "queued" and "locations.cancel" or "locations.update_cache")
		button:setVariant(scan and "secondary" or "primary")
	end
	local path = self.location.url or self.location.path
	if scan == "queued" then
		path = localization:get("locations.scan_queued")
	elseif scan == "running" and status.stage ~= "idle" then
		local key = "notifications.type.library_" .. status.stage
		local stage = localization:get(key)
		if stage == key then stage = status.stage end
		path = status.total > 0
			and localization:get("locations.scan_progress", {stage = stage, current = status.current, total = status.total})
			or localization:get("locations.scan_busy", {stage = stage})
	end
	if self.path:getText() ~= path then self.path:setText(path) end
end

return LocationRow
