local Screen = require("yi.Screen")
local SequenceView = require("sphere.views.SequenceView")
local S = require("gui.composition.Strategies")
local View = require("gui.View")

---@class yi.Gameplay : yi.Screen
---@operator call: yi.Gameplay
local Gameplay = Screen + {}

---@param yi yi.UserInterface
function Gameplay:new(yi)
	Screen.new(self)
	self.yi = yi
	self.game = yi.game
	self.sequence_view = SequenceView()
	self.game_interactor = self.game.gameInteractor
	self.gameplay_interactor = self.game.gameplayInteractor
end

function Gameplay:enter()
	local sv = self.sequence_view
	sv.game = self.game ---@diagnostic disable-line
	sv.subscreen = "gameplay" ---@diagnostic disable-line
	sv:setSequenceConfig(self.game.noteSkinModel.noteSkin.playField)
	sv:load()
end

function Gameplay:exit()
	self.gameplay_interactor:unloadGameplay()
	self.sequence_view:unload()
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
			self.yi:setScreen("result")
		else
			self.yi:setScreen("select")
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
