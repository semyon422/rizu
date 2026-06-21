local Screen = require("gui.Screen")
local SequenceView = require("sphere.views.SequenceView")

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
end

function Gameplay:enter()
	local sv = self.sequence_view
	sv.game = self.game ---@diagnostic disable-line
	sv.subscreen = "gameplay" ---@diagnostic disable-line
	self.game.gameInteractor:loadGameplaySelectedChart()
	sv:setSequenceConfig(self.game.noteSkinModel.noteSkin.playField)
	sv:load()
	love.keyboard.setKeyRepeat(false)
	love.keyboard.setTextInput(false)
	love.mouse.setVisible(false)
end

function Gameplay:exit()
	self.gameplay_interactor:unloadGameplay()
	self.sequence_view:unload()
	love.keyboard.setKeyRepeat(true)
	love.keyboard.setTextInput(true)
	love.mouse.setVisible(true)
end

function Gameplay:update(dt)
	self.sequence_view:update(dt)
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
			--self.ui:setScreen("result")
		else
			self.ui:setScreen("select")
		end

		return true
	end

	return false
end

function Gameplay:receive(event)
	self.game.gameplayInteractor:receive(event)
	self.sequence_view:receive(event)
	Screen.receive(self, event)
end

return Gameplay
