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

	self.clear_status = self.root:add(ClearStatus())
	self.clear_status:setAlignment(0.5, 0.5)
	self.clear_status:setPivot(0.5, 0.5)

	self.root:setOpacity(0)
end

function Gameplay:enter()
	self.ui.command_registry:pushContext("gameplay_commands", self.ui.gameplay_commands)
	local sequence_view = self.sequence_view
	sequence_view.game = self.game
	sequence_view.subscreen = "gameplay"
	sequence_view:setSequenceConfig(self.game.noteSkinModel.noteSkin.playField)
	sequence_view:load()
	love.keyboard.setKeyRepeat(false)
	love.keyboard.setTextInput(false)
	love.mouse.setVisible(false)
	self.is_playing = true
	self.sequence_canvas.playing = true
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
end

function Gameplay:exit()
	self.ui.command_registry:popContext("gameplay_commands")
	self.gameplay_interactor:unloadGameplay()
	self.sequence_canvas.playing = false
	self.sequence_view:unload()
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
		interactor:changePlayState(state == "pause" and "play" or "pause")
	elseif inputs:consumeActionJustPressed(UiActions.gameplay_retry) then
		interactor:changePlayState("retry")
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
end

function Gameplay:observeCompletion()
	if self.game.rhythm_engine:getProgress() < 1 then
		return
	end

	self.is_playing = false
	self.sequence_canvas.playing = false
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
	if self.is_playing then
		self:observeCompletion()
	end
end

---@param event {name: string, time: number, [integer]: any}
function Gameplay:receive(event)
	self.gameplay_interactor:receive(event)
	self.sequence_canvas:receive(event)
end

return Gameplay
