local Screen = require("gui.Screen")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Resources = require("ui.Resources")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local Colors = require("ui.Colors")
local Background = require("ui.views.Background")

---@class ui.screens.result.Result : gui.Screen
---@operator call: ui.screens.result.Result
local Result = Screen + {}

---@param ui ui.UserInterface
function Result:new(ui)
	Screen.new(self)
	self.ui = ui

	self.background = self.root:add(Background(ui.game.backgroundModel, true)):anchorFill(0, 0, 0, 0)

	self.root:add(Image(Resources.atlas, Resources.quads.result_gradient, "fit"))
		:fillWidth(0, 0)
		:setHeight(130)
		:setAlignmentY(1)

	self.content = self.root:add(View()):anchorFill(20, 20, 20, 20)

	local bottom_left = self.content:add(FlowContainer({direction = "column"}))

	self.title = bottom_left:add(Label({
		font_name = "cjk_bold",
		font_size = 48,
		color = Colors.text,
		text = "Title"
	}))

	self.artist = bottom_left:add(Label({
		font_name = "cjk_bold",
		font_size = 24,
		color = Colors.accent,
		text = "Artist"
	}))

	self.chart_name = self.content:add(Label({
		font_name = "cjk_bold",
		font_size = 24,
		color = Colors.text,
		text = "Chart name"
	}))
	self.chart_name:setAlignment(1, 1)

	bottom_left:fitContent()
	bottom_left:setAlignment(0, 1)

	self.root.handles_keyboard_input = true
	self.root.onKeyDown = function(_, event)
		if event.key == "escape" then
			self.ui:setScreen(self.ui.song_select, true)
		end
	end

	self.root:setOpacity(0)
end

function Result:updateInfo()
	local chartview = self.ui.game.chartSelector.chartview

	if not chartview then
		self.ui:setScreen(self.ui.main_menu)
		return
	end

	self.title:setText(chartview.title)
	self.artist:setText(chartview.artist)
	self.chart_name:setText(chartview.name)
end

function Result:enter()
	self:updateInfo()
	self.root:fadeIn(0.3, "OutQuint")
end

function Result:exit()
	Screen.exit(self)
	self.root:fadeOut(0.3, "OutQuint")
end

return Result
