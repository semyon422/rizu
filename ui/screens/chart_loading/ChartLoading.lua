local LoadError = require("ui.screens.chart_loading.LoadError")
local Screen = require("gui.Screen")
local View = require("gui.View")
local CompositeView = require("gui.CompositeView")
local Panel = require("ui.views.Panel")
local Colors = require("ui.Colors")
local UiActions = require("ui.UiActions")
local thread = require("thread")
local delay = require("delay")

---@class ui.screens.chart_loading.ChartLoading : gui.Screen
---@operator call: ui.screens.chart_loading.ChartLoading
local ChartLoading = Screen + {}

---@param ui ui.UserInterface
function ChartLoading:new(ui)
	Screen.new(self)
	self.ui = ui

	-- Song select's backdrop is drawn here too: the two screens show the same pixels, so only
	-- their content fades between them.
	local song_select = ui.song_select
	-- One layer: fading the blur and the scrim on their own lets the blur show through brighter.
	local layer = self.root:add(CompositeView()):anchorFill(0, 0, 0, 0)
	layer:add(Panel({color = Colors.background})):anchorFill(0, 0, 0, 0)
	local backdrop = layer:add(View()):anchorFill(0, 0, 0, 0)
	backdrop:setUpdate(function(_, dt)
		-- A hidden song select no longer runs the blur of a chart that was selected just now.
		if not ui.screen_manager:getVisibleIndex(song_select) then
			song_select.blurred_background:update(dt)
		end
	end)
	backdrop:setDraw(function()
		if song_select.blurred_background.visible then
			song_select.blurred_background:draw()
			song_select.scrim:draw()
		end
	end)

	self.error_view = self.root:add(LoadError()):anchorFill(0, 0, 0, 0)
	self.error_view:setVisible(false)
	self.root:setOpacity(0)
end

---@param message string
function ChartLoading:showError(message)
	self.pending_error = message
end

function ChartLoading:enter()
	local song_select = self.ui.song_select
	if self.ui.screen_manager:getVisibleIndex(song_select) then
		song_select:zoomOut()
	end
	if self.pending_error then
		self.ui.skin_editor = false
		self.failed = true
		self.error_view:setMessage(self.pending_error)
		self.error_view:setVisible(true)
		self.pending_error = nil
		self.root:fadeIn(0.3, "OutQuart")
		return
	end
	self.failed = false
	self.error_view:setVisible(false)
	self.root:fadeIn(0.3, "OutQuart")
	thread.coro(function()
		local ok, loaded = pcall(self.ui.game.gameInteractor.loadGameplaySelectedChartAsync, self.ui.game.gameInteractor)
		if ok and loaded then
			-- Let a few frames pass after the main-thread stall, so the
			-- transition starts with a normal dt instead of the stall's.
			delay.sleep(0.1)
			self.ui:setScreen(self.ui.gameplay, true)
		elseif not ok then
			self.ui.skin_editor = false
			self.failed = true
			self.error_view:setMessage(tostring(loaded))
			self.error_view:setVisible(true)
			self.ui.game.gameplayInteractor.replaying = false
			self.ui.game.gameplayInteractor.autoplay = false
		end
	end)()
end

---@param inputs gui.Inputs
function ChartLoading:onHandleInputs(inputs)
	if self.failed and inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.song_select, true)
	end
end

function ChartLoading:exit()
	Screen.exit(self)
	self.root:fadeOut(0.4, "InQuad")
	return true
end

return ChartLoading
