local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local LocationRow = require("ui.screens.locations.LocationRow")
local Screen = require("gui.Screen")
local ScrollView = require("gui.ScrollView")
local UiActions = require("ui.UiActions")

---@class ui.screens.locations.Locations : gui.Screen
---@operator call: ui.screens.locations.Locations
---@field rows ui.screens.locations.LocationRow[]
---@field scanning_id integer? The location whose update was last started on this screen.
---@field unsubscribe (fun())?
local Locations = Screen + {}

local LIST_WIDTH = 1160

---@param ui ui.UserInterface
function Locations:new(ui)
	Screen.new(self)
	self.ui = ui
	self.root:setPivot(0.5, 0.5)

	local title = self.root:add(Label({font_name = "bold", font_size = 46, text = ui.localization:get("locations.title")}))
	title:setSize(LIST_WIDTH, 58):setAlignment(0.5, 0):setOffset(0, 42)
	local subtitle = self.root:add(Label({
		font_name = "regular", font_size = 18,
		text = ui.localization:get("locations.subtitle"), color = Colors.muted,
	}))
	subtitle:setSize(LIST_WIDTH, 28):setAlignment(0.5, 0):setOffset(0, 102)

	self.content = FlowContainer({direction = "column", gap = 12})
	self.scroll = self.root:add(ScrollView(self.content))
	self.scroll:setSize(LIST_WIDTH, 760):setAlignment(0.5, 0.5):setOffset(0, 28)

	self.empty = self.root:add(Label({
		font_name = "regular", font_size = 20, text = ui.localization:get("locations.empty"),
		color = Colors.muted, align = "center",
	}))
	self.empty:setSize(LIST_WIDTH, 30):setAlignment(0.5, 0.5)

	self.back = self.root:add(Button(ui.localization:get("locations.back"), function() ui:setScreen(ui.main_menu, true) end, {
		variant = "secondary", font_name = "medium", font_size = 18,
	}))
	self.back:setSize(150, 44):setAlignment(0, 1):setOffset(48, -28)
	self.add_button = self.root:add(Button(ui.localization:get("locations.add"), function()
		ui.modal_manager:attachLocationEditor()
	end, {variant = "primary", shape = "capsule", font_name = "medium", font_size = 18}))
	self.add_button:setSize(190, 44):setAlignment(1, 1):setOffset(-48, -28)
end

function Locations:refresh()
	local library = self.ui.api.library
	self.content:clear()
	self.rows = {}
	local displayed = 0
	for _, location in ipairs(library:getLocations()) do
		displayed = displayed + 1
		self.rows[displayed] = self.content:add(LocationRow(location, LIST_WIDTH, self.ui, function(selected)
			if library:getCacheStatus().stage == "idle" then self.scanning_id = selected.id end
			library:toggleCacheUpdate(selected)
		end, function(selected)
			self.ui.modal_manager:attachLocationEditor(selected)
		end, function(selected)
			if library:deleteLocation(selected) then
				self:refresh()
			end
		end))
	end
	self.content:fitContent()
	self.empty:setVisible(displayed == 0)
	self:updateRows(library:getCacheStatus())
end

---@param status rizu.api.CacheStatus
function Locations:updateRows(status)
	for _, row in ipairs(self.rows) do
		row:setScan(status, row.location.id == self.scanning_id)
	end
end

function Locations:enter()
	if self.unsubscribe then self.unsubscribe() end
	self.unsubscribe = self.ui.api.library:on("cache_status_changed", function(status) self:updateRows(status) end)
	self:refresh()
	self.root:fadeIn(0.3, "OutCubic")
	self.root:scaleTo(1, 1, 0.3, "OutQuart")
end

function Locations:exit()
	Screen.exit(self)
	if self.unsubscribe then self.unsubscribe() end
	self.unsubscribe = nil
	-- The scan may report "idle" between its stages, so the started location is only forgotten here.
	self.scanning_id = nil
	self.root:fadeOut(0.2, "OutQuad")
	self.root:scaleTo(1.01, 1.01, 0.3, "OutQuart")
	return true
end

---@param inputs gui.Inputs
function Locations:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.main_menu, true)
	end
end

return Locations
