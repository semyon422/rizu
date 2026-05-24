local Layer = require("ui.Layer")
local SequenceView = require("sphere.views.SequenceView")
local S = require("ui.composition.Strategies")
local View = require("ui.View")

---@class yi.Gameplay : ui.Layer
---@operator call: yi.Gameplay
local Gameplay = Layer + {}

---@param yi yi.UserInterface
function Gameplay:new(yi)
	Layer.new(self)
	self.yi = yi
	self.game = yi.game
	self.sequence_view = SequenceView()

	local sv_view = View()
	sv_view.draw = function() self.sequence_view:draw() end

	self.composition:setRoot(S.Stack({
		sv_view
	}))
end

function Gameplay:start()
	self.game.gameInteractor:loadGameplaySelectedChart()

	local sv = self.sequence_view
	sv.game = self.game
	sv.subscreen = "gameplay"
	sv:setSequenceConfig(self.game.noteSkinModel.noteSkin.playField)
	sv:load()
end

function Gameplay:stop()
	self.game.gameplayInteractor:unloadGameplay()
	self.sequence_view:unload()
end

function Gameplay:update(dt)
	self.sequence_view:update(dt)
	Layer.update(self, dt)
end

function Gameplay:draw()
	love.graphics.push()
	self.sequence_view:draw()
	love.graphics.pop()
	Layer.draw(self)
end

function Gameplay:handleKeyDown(k)
	if k == "escape" then
		self:stop()
		self.yi:setScreen("select")
	end
end

function Gameplay:receive(event)
	Layer.receive(self, event)
	self.game.gameplayInteractor:receive(event)
	self.sequence_view:receive(event)
end

return Gameplay
