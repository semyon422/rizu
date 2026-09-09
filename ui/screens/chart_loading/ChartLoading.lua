local LoadError = require("ui.screens.chart_loading.LoadError")
local Screen = require("gui.Screen")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local Loading = require("ui.screens.chart_loading.Loading")
local UiActions = require("ui.UiActions")
local thread = require("thread")

---@class ui.screens.chart_loading.ChartLoading : gui.Screen
---@operator call: ui.screens.chart_loading.ChartLoading
local ChartLoading = Screen + {}

---@param ui ui.UserInterface
function ChartLoading:new(ui)
	Screen.new(self)
	self.ui = ui

	local content = self.root:add(FlowContainer({
		direction = "row",
		gap = 20,
		align = 0.5,
	}))

	self.content = content
	self.message = content:add(Label({
		font_name = "bold",
		font_size = 36,
		text = ui.localization:get("chart_loading.loading"),
	}))
	self.loading = content:add(Loading())
	content:fitContent()

	content:setAlignment(1, 1)
	content:setPivot(1, 1)
	content:setOffset(-20, -20)

	self.error_view = self.root:add(LoadError()):anchorFill(0, 0, 0, 0)
	self.error_view:setVisible(false)
	self.root:setOpacity(0)
end

---@param message string
function ChartLoading:showError(message)
	self.pending_error = message
end

function ChartLoading:enter()
	if self.pending_error then
		self.failed = true
		self.content:setVisible(false)
		self.error_view:setMessage(self.pending_error)
		self.error_view:setVisible(true)
		self.pending_error = nil
		self.root:fadeIn(0.3, "OutQuart")
		self.content:fitContent()
		return
	end
	self.failed = false
	self.content:setVisible(true)
	self.error_view:setVisible(false)
	self.message:setText(self.ui.localization:get("chart_loading.loading"))
	self.loading:setVisible(true)
	self.content:fitContent()
	self.root:fadeIn(0.3, "OutQuart")
	thread.coro(function()
		local ok, loaded = pcall(self.ui.game.gameInteractor.loadGameplaySelectedChartAsync, self.ui.game.gameInteractor)
		if ok and loaded then
			self.ui:setScreen(self.ui.gameplay, true)
		elseif not ok then
			self.failed = true
			self.content:setVisible(false)
			self.error_view:setMessage(tostring(loaded))
			self.error_view:setVisible(true)
			self.ui.game.gameplayInteractor.replaying = false
			self.ui.game.gameplayInteractor.aim_replay = nil
			self.ui.game.gameplayInteractor.autoplay = false
		end
	end)()
end

---@param inputs gui.Inputs
function ChartLoading:onHandleInputs(inputs)
	if self.failed and inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.song_select)
	end
end

function ChartLoading:exit()
	Screen.exit(self)
	self.root:fadeOut(0.4, "InQuad")
	return true
end

return ChartLoading
