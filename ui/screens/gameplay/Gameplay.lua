local SdvxPlayfield = require("ui.screens.gameplay.SdvxPlayfield")
local TaikoPlayfield = require("ui.screens.gameplay.TaikoPlayfield")
local CatchPlayfield = require("ui.screens.gameplay.CatchPlayfield")
local Label = require("ui.views.Label")
local AimPlayfield = require("ui.screens.gameplay.AimPlayfield")
local Screen = require("gui.Screen")
local SequenceView = require("sphere.views.SequenceView")
local Colors = require("ui.Colors")
local ClearStatus = require("ui.screens.gameplay.ClearStatus")
local SequenceCanvas = require("ui.screens.gameplay.SequenceCanvas")
local BgaView = require("ui.screens.gameplay.BgaView")
local UiActions = require("ui.UiActions")
local delay = require("delay")
local thread = require("thread")

---@class ui.screens.gameplay.Gameplay : gui.Screen
---@field aim_playfield ui.screens.gameplay.AimPlayfield
---@operator call: ui.screens.gameplay.Gameplay
local Gameplay = Screen + {}

---@param ui ui.UserInterface
function Gameplay:new(ui)
	Screen.new(self)
	self.ui = ui
	self.game = ui.game
	self.sequence_view = SequenceView()
	self.gameplay_interactor = self.game.gameplayInteractor
	self.is_playing = false

	self.bga_view = self.root:add(BgaView(self.game, self.ui.config))
	self.bga_view:anchorPercent(0, 0, 1, 1)
	self.sequence_canvas = self.root:add(SequenceCanvas(self.sequence_view))
	self.aim_playfield = self.root:add(AimPlayfield(self.game)):anchorFill(0, 0, 0, 0)
	self.aim_playfield:setVisible(false)
	self.sdvx_playfield = self.root:add(SdvxPlayfield(self.game)):anchorFill(0, 0, 0, 0)
	self.sdvx_playfield:setVisible(false)
	self.taiko_playfield = self.root:add(TaikoPlayfield(self.game)):anchorFill(0, 0, 0, 0)
	self.taiko_playfield:setVisible(false)
	self.catch_playfield = self.root:add(CatchPlayfield(self.game)):anchorFill(0, 0, 0, 0)
	self.catch_playfield:setVisible(false)
	self.aim_summary = self.root:add(Label({font_name = "regular", font_size = 20, text = "", align = "center"}))
	self.aim_summary:setAlignment(0.5, 0.5)
	self.aim_summary:setVisible(false)

	self.clear_status = self.root:add(ClearStatus())
	self.clear_status:setAlignment(0.5, 0.5)
	self.clear_status:setPivot(0.5, 0.5)

	self.root:setOpacity(0)
end

function Gameplay:enter()
	self.ui.command_registry:pushContext("gameplay_commands", self.ui.gameplay_commands)
	local sequence_view = self.sequence_view
	self.is_sdvx = self.game.rhythm_engine.sdvx_rules ~= nil
	self.sdvx_playfield:setVisible(self.is_sdvx)
	self.is_taiko = self.game.rhythm_engine.taiko_rules ~= nil
	self.taiko_playfield:setVisible(self.is_taiko)
	self.is_catch = self.game.rhythm_engine.catch_rules ~= nil
	self.is_aim = self.game.rhythm_engine.aim_rules ~= nil or self.is_catch or self.is_taiko or self.is_sdvx
	self.catch_playfield:setVisible(self.is_catch)
	self.aim_summary:setVisible(false)
	self.aim_playfield:setVisible(self.is_aim and not self.is_catch and not self.is_taiko and not self.is_sdvx)
	self.sequence_canvas:setVisible(not self.is_aim)
	if not self.is_aim then
		sequence_view.game = self.game
		sequence_view.subscreen = "gameplay"
		sequence_view:setSequenceConfig(self.game.noteSkinModel.noteSkin.playField)
		sequence_view:load()
	end
	love.keyboard.setKeyRepeat(false)
	love.keyboard.setTextInput(false)
	love.mouse.setVisible(false)
	self.is_playing = true
	self.sequence_canvas.playing = not self.is_aim
	self.clear_status:hide()

	local cfg = self.ui.config
	local width = cfg:getNumber(cfg.keys.gameplay_viewport_sx)
	local height = cfg:getNumber(cfg.keys.gameplay_viewport_sy)
	local align_x = cfg:getNumber(cfg.keys.gameplay_viewport_x)
	local align_y = cfg:getNumber(cfg.keys.gameplay_viewport_y)
	local min_x = align_x * (1 - width)
	local min_y = align_y * (1 - height)
	self.sequence_canvas:anchorPercent(min_x, min_y, min_x + width, min_y + height)

	self.root:fadeIn(0.4, "OutQuint")
	if self.is_aim and not self.is_catch and not self.is_taiko and not self.is_sdvx then
		self:flush()
		local x, y = love.mouse.getPosition()
		x, y = self.aim_playfield:toChart(x, y)
		self.gameplay_interactor:aimPointer(x, y, self.game.global_timer:getTime())
	end
end

function Gameplay:exit()
	self.is_playing = false
	self.ui.command_registry:popContext("gameplay_commands")
	self.gameplay_interactor:unloadGameplay()
	self.sequence_canvas.playing = false
	if not self.is_aim then
		self.sequence_view:unload()
	end
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
	self.sequence_canvas.playing = false
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
		if not self.is_catch and not self.is_taiko and not self.is_sdvx and (event.name == "mousemoved" or event.name == "mousepressed" or event.name == "mousereleased") then
			local x, y = self.aim_playfield:toChart(event[1], event[2])
			self.gameplay_interactor:aimPointer(x, y, event.time)
		end
		self.gameplay_interactor:receive(event)
		return
	end
	self.gameplay_interactor:receive(event)
	self.sequence_canvas:receive(event)
end

return Gameplay
