local IUserInterface = require("sphere.IUserInterface")
local fonts = require("sphere.assets.fonts")

local GameView = require("ui.views.GameView")
local SelectView = require("ui.views.SelectView")
local ResultView = require("ui.views.ResultView")
local GameplayView = require("ui.views.GameplayView")
local MultiplayerView = require("ui.views.MultiplayerView")

---@class ui.UserInterface: sphere.IUserInterface
---@operator call: ui.UserInterface
---@field selectView ui.ScreenView
local UserInterface = IUserInterface + {}

---@param game sphere.GameController
function UserInterface:new(game)
	self.gameView = GameView(game, self)
	self.selectView = SelectView(game)
	self.resultView = ResultView(game)
	self.gameplayView = GameplayView(game)
	self.multiplayerView = MultiplayerView(game)

	self.configs = game.persistence.configModel.configs
	self.screenshotModel = game.app.screenshotModel
end

function UserInterface:load()
	self.gameView:load()

	local fonts_dpi = self.configs.settings.graphics.fonts_dpi
	if fonts_dpi ~= fonts.dpi then
		fonts.dpi = fonts_dpi
		fonts.reset()
	end
end

function UserInterface:unload()
	self.gameView:unload()
end

---@param dt number
function UserInterface:update(dt)
	self.gameView:update(dt)
end

function UserInterface:draw()
	self.gameView:draw()
end

---@param event table
function UserInterface:receive(event)
	self.gameView:receive(event)

	local screenshot = self.configs.settings.input.screenshot

	if event.name == "keypressed" and event[1] == screenshot.capture then
		local open = love.keyboard.isDown(screenshot.open)
		self.screenshotModel:capture(open)
	end
end

return UserInterface
