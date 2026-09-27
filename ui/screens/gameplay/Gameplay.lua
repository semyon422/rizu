local GameplayPlayfield = require("rizu.gameplay.Playfield")
local View = require("gui.View")
local Label = require("ui.views.Label")
local Screen = require("gui.Screen")
local Colors = require("ui.Colors")
local ClearStatus = require("ui.screens.gameplay.ClearStatus")
local BgaView = require("ui.screens.gameplay.BgaView")
local PauseOverlay = require("ui.screens.gameplay.PauseOverlay")
local PauseHoldOverlay = require("ui.screens.gameplay.PauseHoldOverlay")
local RestartOverlay = require("ui.screens.gameplay.RestartOverlay")
local Window = require("ui.views.Window")
local FlowContainer = require("gui.layout.FlowContainer")
local Slider = require("ui.views.form.Slider")
local UiActions = require("ui.UiActions")
local delay = require("delay")
local thread = require("thread")

---@class ui.screens.gameplay.Gameplay : gui.Screen
---@field gameplay_playfield rizu.gameplay.Playfield
---@field gameplay_playfield_view gui.View
---@field gameplay_hud_view gui.View
---@field skin_editor_window ui.views.Window
---@field skin_editor_controls gui.layout.FlowContainer
---@field skin_editor_properties rizu.skin.base.rizu_mania.ManiaPlayfieldRenderer.Property[]
---@field skin_editor_status ui.views.Label
---@operator call: ui.screens.gameplay.Gameplay
local Gameplay = Screen + {}

---@param ui ui.UserInterface
function Gameplay:new(ui)
	Screen.new(self)
	self.ui = ui
	self.game = ui.game
	self.gameplay_interactor = self.game.gameplayInteractor
	self.is_playing = false
	self.was_retrying = false

	self.bga_view = self.root:add(BgaView(self.game, self.ui.config))
	self.bga_view:anchorPercent(0, 0, 1, 1)
	self.gameplay_playfield = GameplayPlayfield(self.game)
	self.gameplay_playfield_view = self.root:add(View()):anchorFill(0, 0, 0, 0)
	self.gameplay_playfield_view:setDraw(function()
		self:drawGameplayPlayfield()
	end)
	self.gameplay_playfield_view:setUpdate(function(_, dt)
		self.gameplay_playfield:update(dt)
	end)
	self.gameplay_hud_view = self.root:add(View()):anchorFill(0, 0, 0, 0)
	self.gameplay_hud_view:setDraw(function()
		self:drawGameplayHud()
	end)
	self.gameplay_hud_view:setUpdate(function(_, dt)
		self:updateGameplayHud(dt)
	end)
	self.aim_summary = self.root:add(Label({font_name = "regular", font_size = 20, text = "", align = "center"}))
	self.aim_summary:setAlignment(0.5, 0.5)
	self.aim_summary:setVisible(false)

	self.clear_status = self.root:add(ClearStatus())
	self.clear_status:setAlignment(0.5, 0.5)
	self.clear_status:setPivot(0.5, 0.5)

	self.pause_overlay = self.root:add(PauseOverlay(
		ui.localization,
		function() self.gameplay_interactor:changePlayState("play") end,
		function() self.gameplay_interactor:changePlayState("retry") end,
		function()
			self.ui:setScreen(self.ui.song_select, true)
			self.is_playing = false
		end
	))
	self.pause_hold_overlay = self.root:add(PauseHoldOverlay(ui.localization))
	self.restart_overlay = self.root:add(RestartOverlay())
	self.skin_editor_window = self.root:add(Window(
		ui.localization:get("gameplay.skin_editor.title"), 640, 420
	))
	self.skin_editor_window:setAlignment(0.5, 0.5)
	self.skin_editor_window:setInactiveOpacity(0.35)
	self.skin_editor_window:setVisible(false)
	self.skin_editor_controls = self.skin_editor_window:addContent(FlowContainer({direction = "column", gap = 14}))
	self.skin_editor_status = self.skin_editor_controls:add(Label({
		font_name = "regular", font_size = 14, text = "",
	}))

	self.root:setOpacity(0)
end

function Gameplay:unload()
	self.gameplay_playfield:unload()
	Screen.unload(self)
end

function Gameplay:enter()
	self.ui.command_registry:pushContext("gameplay_commands", self.ui.gameplay_commands)
	self.is_sdvx = self.game.rhythm_engine.sdvx_rules ~= nil
	self.is_taiko = self.game.rhythm_engine.taiko_rules ~= nil
	self.is_catch = self.game.rhythm_engine.catch_rules ~= nil
	self.gameplay_playfield:refresh()
	self.is_aim = self.gameplay_playfield:isExperimental()
	self.aim_summary:setVisible(false)
	love.keyboard.setKeyRepeat(false)
	love.keyboard.setTextInput(false)
	love.mouse.setVisible(self.ui.skin_editor)
	self.is_playing = true
	self.skin_editor_window:setVisible(self.ui.skin_editor)
	if self.ui.skin_editor then
		self:refreshSkinEditor()
	end
	self.clear_status:hide()
	self.pause_overlay:hide()
	self.pause_hold_overlay:setProgress(0)
	self.was_retrying = false
	self.restart_overlay:reset()

	self.root:fadeIn(0.4, "OutQuint")
	if self.gameplay_playfield:usesPointer() then
		self:flush()
		local x, y = love.mouse.getPosition()
		x, y = self:toGameplayChart(x, y)
		self.gameplay_interactor:aimPointer(x, y, self.game.global_timer:getTime())
	end
end

---@return number
---@return number
---@return love.Transform Maps viewport coordinates to drawable pixels
function Gameplay:getGameplayViewport()
	local cfg = self.ui.config
	local width = self.width * cfg:getNumber(cfg.keys.gameplay_viewport_sx)
	local height = self.height * cfg:getNumber(cfg.keys.gameplay_viewport_sy)
	local transform = self._gameplay_viewport_transform
	if not transform then
		transform = love.math.newTransform()
		self._gameplay_viewport_transform = transform
	end
	transform:reset()
	transform:translate(
		(self.width - width) * cfg:getNumber(cfg.keys.gameplay_viewport_x),
		(self.height - height) * cfg:getNumber(cfg.keys.gameplay_viewport_y)
	)
	return width, height, transform
end

-- Gameplay renderers operate in drawable pixels. This UI-owned bridge cancels
-- the retained UI scale and supplies the configured viewport explicitly.
function Gameplay:drawGameplayPlayfield()
	if not self.gameplay_playfield:usesDirectRenderer() then return end
	local width, height, transform = self:getGameplayViewport()
	local x, y = transform:transformPoint(0, 0)
	love.graphics.push("all")
	love.graphics.scale(1 / self.ui_scale)
	love.graphics.setScissor(x, y, width, height)
	self.gameplay_playfield:draw(width, height, transform)
	love.graphics.setScissor()
	love.graphics.pop()
end

---@param dt number
function Gameplay:updateGameplayHud(dt)
	self.gameplay_playfield:updateHud(dt)
end

function Gameplay:drawGameplayHud()
	local width, height, transform = self:getGameplayViewport()
	if width <= 0 or height <= 0 then return end
	local x, y = transform:transformPoint(0, 0)
	love.graphics.push("all")
	love.graphics.scale(1 / self.ui_scale)
	love.graphics.setScissor(x, y, width, height)
	self.gameplay_playfield:drawHud(width, height, transform)
	love.graphics.setScissor()
	love.graphics.pop()
end

---@param x number Window x coordinate in drawable pixels
---@param y number Window y coordinate in drawable pixels
---@return number
---@return number
function Gameplay:toGameplayChart(x, y)
	local width, height, transform = self:getGameplayViewport()
	return self.gameplay_playfield:toChart(x, y, width, height, transform)
end

function Gameplay:refreshSkinEditor()
	self.skin_editor_controls:clear()
	self.skin_editor_controls:setDirection("column")
	self.skin_editor_controls:setGap(14)
	self.skin_editor_status:setText("")
	self.skin_editor_status:setSize(540, 24)
	local renderer = self.gameplay_interactor.mania_renderer
	self.skin_editor_properties = {}
	if not renderer or not renderer.getProperties then
		self.skin_editor_status:setText(self.ui.localization:get("gameplay.skin_editor.no_properties"))
		self.skin_editor_controls:add(self.skin_editor_status)
		self.skin_editor_controls:fitContent()
		self.skin_editor_window:setContentHeight(math.max(120, self.skin_editor_controls.height))
		return
	end

	self.skin_editor_properties = renderer:getProperties()
	for _, property in ipairs(self.skin_editor_properties) do
		self.skin_editor_controls:add(Slider({
			label = property.label or self.ui.localization:get(property.label_key),
			value = property.get(),
			min = property.min,
			max = property.max,
			step = property.step,
			width = 540,
			value_format = function(value) return tostring(math.floor(value + 0.5)) end,
			on_change = function(value)
				property.set(value)
				local config = self.gameplay_interactor.mania_skin_config
				if not config then
					self.skin_editor_status:setText(self.ui.localization:get("gameplay.skin_editor.save_failed", {
						error = "Skin config is unavailable.",
					}))
					return
				end
				local saved, save_error = config:save(
					self.game.fs, self.gameplay_interactor.mania_skin_config_path
				)
				if saved then
					self.skin_editor_status:setText(self.ui.localization:get("gameplay.skin_editor.saved"))
				else
					self.skin_editor_status:setText(self.ui.localization:get("gameplay.skin_editor.save_failed", {
						error = tostring(save_error),
					}))
				end
			end,
		}))
	end
	self.skin_editor_controls:add(self.skin_editor_status)
	self.skin_editor_controls:fitContent()
	self.skin_editor_window:setContentHeight(math.max(120, self.skin_editor_controls.height))
end

function Gameplay:exit()
	self.is_playing = false
	self.skin_editor_window:setVisible(false)
	self.ui.skin_editor = false
	self.pause_overlay:hide()
	self.pause_hold_overlay:setProgress(0)
	self.was_retrying = false
	self.restart_overlay:reset()
	self.ui.command_registry:popContext("gameplay_commands")
	self.gameplay_interactor:unloadGameplay()
	love.keyboard.setKeyRepeat(true)
	love.keyboard.setTextInput(true)
	love.mouse.setVisible(true)

	self.root:fadeOut(1, "OutQuint")
end

---@param inputs gui.Inputs
function Gameplay:onHandleInputs(inputs)
	local interactor = self.gameplay_interactor
	if inputs:consumeActionJustPressed(UiActions.gameplay_quit) then
		self.ui:setScreen(self.ui.song_select, true)
		self.is_playing = false
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_pause) then
		local state = self.game.pauseModel.state
		if state == "play" then
			interactor:changePlayState("pause")
		elseif state == "pause" then
			interactor:changePlayState("play")
		elseif state == "pause-play" then
			interactor:changePlayState("pause")
		end
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_retry) then
		local state = self.game.pauseModel.state
		if state == "play" or state == "pause" then
			interactor:changePlayState("retry")
		end
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_skip_intro) then
		interactor:skipIntro()
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_offset_decrease) then
		self.game.offsetController:increaseLocalOffset(-0.001)
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_offset_increase) then
		self.game.offsetController:increaseLocalOffset(0.001)
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_offset_reset) then
		self.game.offsetController:resetLocalOffset()
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_play_speed_decrease) then
		interactor:increasePlaySpeed(-1)
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_play_speed_increase) then
		interactor:increasePlaySpeed(1)
	end

	local state = self.game.pauseModel.state
	if inputs:consumeActionJustReleased(UiActions.gameplay_pause) and state == "play-pause" then
		interactor:changePlayState("play")
	end
	if inputs:consumeActionJustReleased(UiActions.gameplay_retry) then
		if state == "play-retry" then
			interactor:changePlayState("play")
		elseif state == "pause-retry" then
			interactor:changePlayState("pause")
		end
	end
end

function Gameplay:observeCompletion()
	if self.game.rhythm_engine:getProgress() < 1 then
		return
	end

	self.is_playing = false
	if self.is_aim then
		self.gameplay_interactor:saveAimReplay()
		self.gameplay_interactor.aim_complete = true
		self.gameplay_interactor:pause()
		local rules = self.game.rhythm_engine.aim_rules or self.game.rhythm_engine.catch_rules or self.game.rhythm_engine.taiko_rules or self.game.rhythm_engine.sdvx_rules
		self.aim_summary:setText(("Hit %d / Miss %d\n%s\nEnter: back | R: replay | Retry: new attempt"):format(
			rules.hits, rules.misses, self.gameplay_interactor.aim_status or "Autoplay / replay — no score saved"))
		self.aim_summary:setVisible(true)
		return
	end
	local base_score = self.game.rhythm_engine.score_engine.scores.base
	if base_score.missCount == 0 then
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

---@param dt number
function Gameplay:update(dt)
	Screen.update(self, dt)
	local pause_model = self.game.pauseModel
	local state = pause_model.state
	if state == "play-pause" then
		self.pause_hold_overlay:setPrompt("pause")
		self.pause_hold_overlay:setProgress(pause_model.progress)
		self.pause_overlay:setReveal(0)
	elseif state == "play-retry" or state == "pause-retry" then
		self.pause_hold_overlay:setProgress(0)
		self.pause_overlay:setReveal(state == "pause-retry" and 1 or 0)
	elseif state == "pause-play" then
		self.pause_hold_overlay:setProgress(0)
		self.pause_overlay:setReveal(1 - pause_model.progress)
	elseif state:sub(1, 5) == "pause" then
		self.pause_hold_overlay:setProgress(0)
		self.pause_overlay:setReveal(1)
	else
		self.pause_hold_overlay:setProgress(0)
		self.pause_overlay:setReveal(0)
	end

	local retrying = state == "play-retry" or state == "pause-retry"
	if retrying then
		self.restart_overlay:setProgress(pause_model.progress)
	elseif self.was_retrying then
		self.restart_overlay:retract()
	end
	self.was_retrying = retrying

	if self.is_aim and self.gameplay_interactor.loaded then
		self.gameplay_interactor:update(true)
		if not self.is_playing and self.game.rhythm_engine:getProgress() < 1 then
			self.is_playing = true
			self.aim_summary:setVisible(false)
			self.clear_status:hide()
		end
	end
	if self.is_playing then
		self:observeCompletion()
	end
end

---@param event {name: string, time: number, [integer]: any}
function Gameplay:receive(event)
	if self.is_aim then
		if not self.is_playing and event.name == "keypressed" then
			if event[1] == "return" then
				self.ui:setScreen(self.ui.song_select)
				return true
			elseif event[1] == "r" then
				local meta = self.game.rhythm_engine.chartmeta
				local ok, err = self.gameplay_interactor:loadAimReplay(meta.hash, meta.index, self.is_sdvx and "sdvx" or self.is_taiko and "taiko" or self.is_catch)
				if ok then
					self.gameplay_interactor:retry()
					self.is_playing = true
					self.aim_summary:setVisible(false)
				else
					self.aim_summary:setText(err .. "\nEnter: back")
				end
				return true
			end
		end
		if self.gameplay_playfield:usesPointer() and (event.name == "mousemoved" or event.name == "mousepressed" or event.name == "mousereleased") then
			local x, y = self:toGameplayChart(event[1], event[2])
			self.gameplay_interactor:aimPointer(x, y, event.time)
		end
		self.gameplay_interactor:receive(event)
		return
	end
	self.gameplay_interactor:receive(event)
end

return Gameplay
