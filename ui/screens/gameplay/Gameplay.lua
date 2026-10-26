local View = require("gui.View")
local CompositeView = require("gui.CompositeView")
local Label = require("ui.views.Label")
local Screen = require("gui.Screen")
local Colors = require("ui.Colors")
local AdjustmentOverlay = require("ui.screens.gameplay.AdjustmentOverlay")
local ClearStatus = require("ui.screens.gameplay.ClearStatus")
local PauseOverlay = require("ui.screens.gameplay.PauseOverlay")
local PauseHoldOverlay = require("ui.screens.gameplay.PauseHoldOverlay")
local RestartOverlay = require("ui.screens.gameplay.RestartOverlay")
local SkinEditor = require("ui.screens.gameplay.SkinEditor")
local Background = require("ui.views.Background")
local UiConfig = require("ui.UiConfig")
local UiActions = require("ui.UiActions")
local delay = require("delay")
local thread = require("thread")

---@class ui.screens.gameplay.Gameplay : gui.Screen
---@field gameplay rizu.api.Gameplay
---@field gameplay_playfield_view gui.View
---@field gameplay_hud_view gui.View
---@field skin_editor ui.screens.gameplay.SkinEditor
---@field mouse_visible boolean? Cursor visibility this screen last applied, nil while not entered
---@operator call: ui.screens.gameplay.Gameplay
local Gameplay = Screen + {}

---@param ui ui.UserInterface
function Gameplay:new(ui)
	Screen.new(self)
	self.ui = ui
	self.gameplay = ui.api.gameplay
	self.is_playing = false
	self.was_retrying = false

	self.background = self.root:add(Background(ui.api.media))
	self.background:anchorFill(0, 0, 0, 0)
	local function setBrightness(brightness) self.background:setBrightness(brightness, true) end
	setBrightness(ui.config:getNumber(UiConfig.keys.gameplay_background_brightness))
	ui.config:subscribeNumber(UiConfig.keys.gameplay_background_brightness, setBrightness)

	-- The skin draws with its own colours and ignores the screen opacity. As one layer it fades
	-- through a canvas, and draws straight to the screen again once the fade has ended.
	local skin_layer = self.root:add(CompositeView()):anchorFill(0, 0, 0, 0)
	self.gameplay_playfield_view = skin_layer:add(View()):anchorFill(0, 0, 0, 0)
	self.gameplay_playfield_view:setDraw(function()
		self:drawGameplayPlayfield()
	end)
	self.gameplay_hud_view = skin_layer:add(View()):anchorFill(0, 0, 0, 0)
	self.gameplay_hud_view:setDraw(function()
		self:drawGameplayHud()
	end)
	self.summary = self.root:add(Label({font_name = "regular", font_size = 20, text = "", align = "center"}))
	self.summary:setAlignment(0.5, 0.5)
	self.summary:setVisible(false)

	self.adjust_overlay = self.root:add(AdjustmentOverlay(ui.localization))

	self.clear_status = self.root:add(ClearStatus())
	self.clear_status:setAlignment(0.5, 0.5)
	self.clear_status:setPivot(0.5, 0.5)

	local l = ui.localization
	local function retry() self.gameplay:retry() end
	local function leave()
		self.ui:setScreen(self.ui.song_select, true)
		self.is_playing = false
	end
	self.pause_overlay = self.root:add(PauseOverlay(l:get("gameplay.pause.title"), {
		{l:get("gameplay.pause.continue"), function() self.gameplay:resume() end, "continue"},
		{l:get("gameplay.pause.restart"), retry, "restart"},
		{l:get("gameplay.pause.leave"), leave, "leave"},
	}))
	self.fail_overlay = self.root:add(PauseOverlay(l:get("gameplay.fail.title"), {
		{l:get("gameplay.pause.restart"), retry, "restart"},
		{l:get("gameplay.pause.leave"), leave, "leave"},
	}))
	self.pause_hold_overlay = self.root:add(PauseHoldOverlay(ui.localization))
	self.restart_overlay = self.root:add(RestartOverlay())
	self.skin_editor = self.root:add(SkinEditor(ui))

	self.root:setOpacity(0)
end

function Gameplay:showAdjustment()
	self.adjust_overlay:show(self.gameplay:getScrollSpeedText(), self.gameplay:getLocalOffset())
end

function Gameplay:unload()
	Screen.unload(self)
end

function Gameplay:enter()
	assert(self.gameplay:isLoaded(), "gameplay playfield is not ready")
	self.is_unscored = not self.gameplay:hasScoring()
	self.summary:setVisible(false)
	love.keyboard.setKeyRepeat(false)
	love.keyboard.setTextInput(false)
	self.mouse_visible = self.ui.skin_editor
	love.mouse.setVisible(self.mouse_visible)
	self.is_playing = true
	if self.ui.skin_editor then
		self.skin_editor:open()
	end
	self.clear_status:hide()
	self.pause_overlay:hide()
	self.fail_overlay:hide()
	self.pause_hold_overlay:setProgress(0)
	self.was_retrying = false
	self.restart_overlay:reset()
	self.adjust_overlay:hide()

	self.root:fadeIn(0.4, "OutQuint")
	if self.gameplay:usesPointer() then
		self:flush()
		local x, y = love.mouse.getPosition()
		self:moveGameplayPointer(x, y)
	end
end

---@return number
---@return number
---@return love.Transform Maps viewport coordinates to drawable pixels
function Gameplay:getGameplayViewport()
	local cfg = self.ui.config
	local width = self.width * cfg:getNumber(cfg.keys.gameplay_viewport_sx)
	local height = self.height * cfg:getNumber(cfg.keys.gameplay_viewport_sy)
	local x = (self.width - width) * cfg:getNumber(cfg.keys.gameplay_viewport_x)
	local y = (self.height - height) * cfg:getNumber(cfg.keys.gameplay_viewport_y)
	if self.ui.skin_editor and self.width > 0 then
		local window_x, window_y, scale = SkinEditor.getWindow(self.width, self.height, self.ui_scale)
		x, y = window_x + x * scale, window_y + y * scale
		width, height = width * scale, height * scale
	end
	local transform = self._gameplay_viewport_transform
	if not transform then
		transform = love.math.newTransform()
		self._gameplay_viewport_transform = transform
	end
	transform:reset()
	transform:translate(x, y)
	return width, height, transform
end

-- Gameplay renderers operate in drawable pixels. This UI-owned bridge cancels
-- the retained UI scale and supplies the configured viewport explicitly.
function Gameplay:drawGameplayPlayfield()
	local width, height, transform = self:getGameplayViewport()
	if width <= 0 or height <= 0 then return end
	local x, y = transform:transformPoint(0, 0)
	love.graphics.push("all")
	love.graphics.scale(1 / self.ui_scale)
	love.graphics.setScissor(x, y, width, height)
	self.gameplay:drawPlayfield(width, height, transform)
	love.graphics.setScissor()
	love.graphics.pop()
end

function Gameplay:drawGameplayHud()
	local width, height, transform = self:getGameplayViewport()
	if width <= 0 or height <= 0 then return end
	local x, y = transform:transformPoint(0, 0)
	love.graphics.push("all")
	love.graphics.scale(1 / self.ui_scale)
	love.graphics.setScissor(x, y, width, height)
	self.gameplay:drawHud(width, height, transform)
	love.graphics.setScissor()
	love.graphics.pop()
end

---@param x number Window x coordinate in drawable pixels
---@param y number Window y coordinate in drawable pixels
---@param time number?
function Gameplay:moveGameplayPointer(x, y, time)
	local width, height, transform = self:getGameplayViewport()
	self.gameplay:movePointer(x, y, width, height, transform, time)
end

function Gameplay:exit()
	self.is_playing = false
	self.skin_editor:close()
	self.ui.skin_editor = false
	self.pause_overlay:hide()
	self.fail_overlay:hide()
	self.pause_hold_overlay:setProgress(0)
	self.was_retrying = false
	self.restart_overlay:reset()
	self.gameplay:close()
	love.keyboard.setKeyRepeat(true)
	love.keyboard.setTextInput(true)
	self.mouse_visible = nil
	love.mouse.setVisible(true)

	self.root:fadeOut(1, "OutQuint")
end

---@param inputs gui.Inputs
function Gameplay:onHandleInputs(inputs)
	local gameplay = self.gameplay
	if inputs:consumeActionJustPressed(UiActions.gameplay_quit) then
		self.ui:setScreen(self.ui.song_select, true)
		self.is_playing = false
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_pause) then
		local state = gameplay:getState()
		if state == "play" or state == "pause-play" then
			gameplay:pause()
		elseif state == "pause" then
			gameplay:resume()
		end
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_retry) then
		local state = gameplay:getState()
		if state == "play" or state == "pause" then
			gameplay:retry()
		end
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_skip_intro) then
		gameplay:skipIntro()
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_offset_decrease) then
		gameplay:changeLocalOffset(-0.001)
		self:showAdjustment()
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_offset_increase) then
		gameplay:changeLocalOffset(0.001)
		self:showAdjustment()
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_offset_reset) then
		gameplay:resetLocalOffset()
		self:showAdjustment()
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_play_speed_decrease) then
		gameplay:changeScrollSpeed(-1)
		self:showAdjustment()
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_play_speed_increase) then
		gameplay:changeScrollSpeed(1)
		self:showAdjustment()
	end

	local state = gameplay:getState()
	if inputs:consumeActionJustReleased(UiActions.gameplay_pause) and state == "play-pause" then
		gameplay:resume()
	end
	if inputs:consumeActionJustReleased(UiActions.gameplay_retry) then
		if state == "play-retry" then
			gameplay:resume()
		elseif state == "pause-retry" then
			gameplay:pause()
		end
	end
end

function Gameplay:observeCompletion()
	local gameplay = self.gameplay
	if gameplay:getProgress() < 1 then
		return
	end

	self.is_playing = false
	if self.is_unscored then
		local status = gameplay:finish()
		local hits, misses = gameplay:getHitCounts()
		self.summary:setText(("Hit %d / Miss %d\n%s\nEnter: back | R: replay | Retry: new attempt"):format(
			hits, misses, status or "Autoplay / replay — no score saved"))
		self.summary:setVisible(true)
		return
	end
	local _, misses = gameplay:getHitCounts()
	if misses == 0 then
		self.clear_status:bind("FULL COMBO", Colors.grade_s)
	else
		self.clear_status:bind("STAGE COMPLETED", Colors.text)
	end

	thread.coro(function()
		delay.sleep(0.16)
		self.clear_status:show()
		delay.sleep(1)
		self.ui:setScreen(self.ui.result, true)
	end)()
end

---@param state string
function Gameplay:updateMouseVisibility(state)
	-- nil after exit: the outgoing screen keeps updating during its fade-out
	if self.mouse_visible == nil then return end
	local mouse_visible = self.ui.skin_editor or state:sub(1, 5) == "pause"
	if mouse_visible ~= self.mouse_visible then
		self.mouse_visible = mouse_visible
		love.mouse.setVisible(mouse_visible)
	end
end

---@param dt number
function Gameplay:update(dt)
	Screen.update(self, dt)
	local gameplay = self.gameplay
	local state = gameplay:getState()
	local progress = gameplay:getStateProgress()
	if state == "play-pause" then
		self.pause_hold_overlay:setPrompt("pause")
		self.pause_hold_overlay:setProgress(progress)
		self.pause_overlay:setReveal(0)
	elseif state == "play-retry" or state == "pause-retry" then
		self.pause_hold_overlay:setProgress(0)
		self.pause_overlay:setReveal(state == "pause-retry" and 1 or 0)
	elseif state == "pause-play" then
		self.pause_hold_overlay:setProgress(0)
		self.pause_overlay:setReveal(1 - progress)
	elseif state:sub(1, 5) == "pause" then
		self.pause_hold_overlay:setProgress(0)
		self.pause_overlay:setReveal(1)
	else
		self.pause_hold_overlay:setProgress(0)
		self.pause_overlay:setReveal(0)
	end

	-- The fail overlay stands in for the pause one, also while a retry is held from it.
	local fail_stopped = gameplay:isFailStopped()
	self.fail_overlay:setReveal(fail_stopped and 1 or 0)
	if fail_stopped then
		self.pause_overlay:setReveal(0)
	end

	self:updateMouseVisibility(state)

	local retrying = state == "play-retry" or state == "pause-retry"
	if retrying then
		self.restart_overlay:setProgress(progress)
	elseif self.was_retrying then
		self.restart_overlay:retract()
	end
	self.was_retrying = retrying

	if self.is_unscored and gameplay:isLoaded() then
		gameplay:update(dt)
		if not self.is_playing and gameplay:getProgress() < 1 then
			self.is_playing = true
			self.summary:setVisible(false)
			self.clear_status:hide()
		end
	end
	if self.is_playing then
		self:observeCompletion()
	end
end

---@param event {name: string, time: number, [integer]: any}
function Gameplay:receive(event)
	if self.is_unscored then
		if not self.is_playing and event.name == "keypressed" then
			if event[1] == "return" then
				self.ui:setScreen(self.ui.song_select)
				return true
			elseif event[1] == "r" then
				local ok, err = self.gameplay:watchLocalReplay()
				if ok then
					self.is_playing = true
					self.summary:setVisible(false)
				else
					self.summary:setText(err .. "\nEnter: back")
				end
				return true
			end
		end
		if self.gameplay:usesPointer() and (event.name == "mousemoved" or event.name == "mousepressed" or event.name == "mousereleased") then
			self:moveGameplayPointer(event[1], event[2], event.time)
		end
		self.gameplay:receive(event)
		return
	end
	self.gameplay:receive(event)
end

return Gameplay
