local Screen = require("gui.Screen")
local SequenceView = require("sphere.views.SequenceView")
local S = require("gui.composition.Strategies")
local ClearStatus = require("yi.views.gameplay.ClearStatus")
local Colors = require("yi.Colors")
local delay = require("delay")
local thread = require("thread")
local GameplayCommands = require("ui.commands.GameplayCommands")

---@class yi.Gameplay : gui.Screen
---@operator call: yi.Gameplay
local Gameplay = Screen + {}

---@param ui yi.UserInterface
function Gameplay:new(ui)
	Screen.new(self)
	self.ui = ui
	self.game = ui.game
	self.sequence_view = SequenceView()
	self.game_interactor = self.game.gameInteractor
	self.gameplay_interactor = self.game.gameplayInteractor
	self.play_progress = self.game.rhythm_engine.play_progress

	self.clear_status = ClearStatus()
	self.clear_status:setPivot(0, 0.5)
	self.is_playing = true
	self.commands = GameplayCommands(ui)

	self.root = S.Stack({
		self.clear_status
	})
end

function Gameplay:enter()
	local sv = self.sequence_view
	sv.game = self.game ---@diagnostic disable-line
	sv.subscreen = "gameplay" ---@diagnostic disable-line
	sv:setSequenceConfig(self.game.noteSkinModel.noteSkin.playField)
	sv:load()
	love.keyboard.setKeyRepeat(false)
	love.keyboard.setTextInput(false)
	love.mouse.setVisible(false)
	self.is_playing = true
	self.clear_status:hide()
	self.ui.command_registry:pushContext("gameplay", self.commands)
end

function Gameplay:exit()
	self.ui.command_registry:popContext("gameplay")
	self.gameplay_interactor:unloadGameplay()
	self.sequence_view:unload()
	love.keyboard.setKeyRepeat(true)
	love.keyboard.setTextInput(true)
	love.mouse.setVisible(true)
end

function Gameplay:observeCompletion()
	local p = self.game.rhythm_engine:getProgress()

	if p < 1 then
		return
	end

	self.is_playing = false

	local base = self.game.rhythm_engine.score_engine.scores.base

	if base.missCount == 0 then
		self.clear_status:bind("FULL COMBO", Colors.grade_s)
	else
		self.clear_status:bind("STAGE COMPLETED", Colors.text)
	end

	-- Bad things will happen if you change the resolution while this is running...
	thread.coro(function()
		delay.sleep(0.16)
		self.clear_status:show()
		delay.sleep(1)
		self.ui:setScreen("result")
	end)()
end

function Gameplay:update(dt)
	self.sequence_view:update(dt)

	if self.is_playing then
		self:observeCompletion()
	end

	Screen.update(self, dt)
end

function Gameplay:draw()
	love.graphics.push()
	self.sequence_view:draw()
	love.graphics.pop()
	Screen.draw(self)
end

function Gameplay:handleKeyDown(k)
	if k == "escape" then
		if self.gameplay_interactor:hasResult() then
			self.ui:setScreen("result")
		else
			self.ui:setScreen("select")
		end
	elseif k == "space" then
		self.gameplay_interactor:skipIntro()
	else
		return false
	end

	return true
end

function Gameplay:receive(event)
	self.game.gameplayInteractor:receive(event)
	self.sequence_view:receive(event)
	Screen.receive(self, event)
end

return Gameplay
