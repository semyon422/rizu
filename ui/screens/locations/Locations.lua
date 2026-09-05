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
local Locations = Screen + {}

local LIST_WIDTH = 1160

---@param ui ui.UserInterface
function Locations:new(ui)
	Screen.new(self)
	self.ui = ui
	self.root:setPivot(0.5, 0.5)

	local title = self.root:add(Label({font_name = "bold", font_size = 46, text = "Local locations"}))
	title:setSize(LIST_WIDTH, 58):setAlignment(0.5, 0):setOffset(0, 42)
	local subtitle = self.root:add(Label({
		font_name = "regular", font_size = 18,
		text = "Manage folders Rizu scans for Charts.", color = Colors.muted,
	}))
	subtitle:setSize(LIST_WIDTH, 28):setAlignment(0.5, 0):setOffset(0, 102)

	self.content = FlowContainer({direction = "column", gap = 12})
	self.scroll = self.root:add(ScrollView(self.content))
	self.scroll:setSize(LIST_WIDTH, 760):setAlignment(0.5, 0.5):setOffset(0, 28)

	self.empty = self.root:add(Label({
		font_name = "regular", font_size = 20, text = "No local locations configured.",
		color = Colors.muted, align = "center",
	}))
	self.empty:setSize(LIST_WIDTH, 30):setAlignment(0.5, 0.5)

	self.back = self.root:add(Button("Back", function() ui:setScreen(ui.main_menu, true) end, {
		variant = "secondary", font_name = "medium", font_size = 18,
	}))
	self.back:setSize(150, 44):setAlignment(0, 1):setOffset(48, -28)
	self.add_button = self.root:add(Button("Add location", function()
		ui.modal_manager:attachLocationEditor()
	end, {variant = "primary", shape = "capsule", font_name = "medium", font_size = 18}))
	self.add_button:setSize(190, 44):setAlignment(1, 1):setOffset(-48, -28)
end

function Locations:refresh()
	local locations = self.ui.game.library.locations
	locations:selectLocations()
	self.content:clear()
	local displayed = 0
	for _, location in ipairs(locations.locations) do
		if not location.is_internal then
			displayed = displayed + 1
			self.content:add(LocationRow(location, LIST_WIDTH, function(selected)
				self.ui.game.selectionActions:updateCacheLocation(selected.id)
			end, function(selected)
				self.ui.modal_manager:attachLocationEditor(selected)
			end, function(selected)
				if locations:deleteLocation(selected.id) then
					self.ui.game.chartSelector:noDebounceRefresh()
					self:refresh()
				end
			end))
		end
	end
	self.content:fitContent()
	self.empty:setVisible(displayed == 0)
end

function Locations:enter()
	self:refresh()
	self.root:fadeIn(0.3, "OutCubic")
	self.root:scaleTo(1, 1, 0.3, "OutQuart")
end

function Locations:exit()
	Screen.exit(self)
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
