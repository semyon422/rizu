local Screen = require("gui.Screen")
local SequenceView = require("sphere.views.SequenceView")
local Colors = require("ui.Colors")
local ClearStatus = require("ui.screens.gameplay.ClearStatus")
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

	self.clear_status = self.root:add(ClearStatus())
	self.clear_status:setAlignment(0.5, 0.5)
	self.clear_status:setPivot(0.5, 0.5)

	self.root.handles_keyboard_input = true
	self.root.onKeyDown = function(_, event)
		if event.key == "escape" then
			if self.gameplay_interactor:hasResult() then
				self.ui:setScreen(self.ui.result)
			else
				self.ui:setScreen(self.ui.song_select)
			end
		elseif event.key == "space" then
			self.gameplay_interactor:skipIntro()
		end
	end
end

function Gameplay:enter()
	local sequence_view = self.sequence_view
	sequence_view.game = self.game
	sequence_view.subscreen = "gameplay"
	sequence_view:setSequenceConfig(self.game.noteSkinModel.noteSkin.playField)
	sequence_view:load()
	love.keyboard.setKeyRepeat(false)
	love.keyboard.setTextInput(false)
	love.mouse.setVisible(false)
	self.is_playing = true
	self.clear_status:hide()
end

function Gameplay:exit()
	self.gameplay_interactor:unloadGameplay()
	self.sequence_view:unload()
	love.keyboard.setKeyRepeat(true)
	love.keyboard.setTextInput(true)
	love.mouse.setVisible(true)
end

function Gameplay:observeCompletion()
	if self.game.rhythm_engine:getProgress() < 1 then
		return
	end

	self.is_playing = false
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
		self.ui:setScreen(self.ui.result)
	end)()
end

---@param dt number
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

---@param event {name: string, [integer]: any}
function Gameplay:receive(event)
	self.gameplay_interactor:receive(event)
	self.sequence_view:receive(event)
end

return Gameplay
