local Screen = require("yi.Screen")
local UIFactory = require("yi.UIFactory")
local S = require("ui.composition.Strategies")
local MainMenuWave = require("yi.views.MainMenuWave")

---@class yi.MainMenu : yi.Screen
---@operator call: yi.MainMenu
local MainMenu = Screen + {}

---@param yi yi.UserInterface
function MainMenu:new(yi)
	Screen.new(self)
	self.yi = yi

	local ui = UIFactory(yi.resources)

	self.composition:setRoot(S.Stack({
		MainMenuWave(),

		S.Anchor({
			pivot = {0.5, 0.5},

			S.Column({
				align = 0.5,
				gap = 20,

				ui:Image({
					image = "rizu",
					size_scale = 0.7,
				}),
				ui:Label({
					y = -4,
					font_size = 24,
					font = "regular",
					text = "[Enter] Play [M] Multiplayer [C] Config",
				}),
			}),

		}),
	}))
end

function MainMenu:draw()
	love.graphics.push("all")
	love.graphics.setCanvas(self.yi.composition.shared_layer_canvas)
	love.graphics.clear()
	Screen.draw(self)
	love.graphics.pop()

	local a = self.transition:get()

	love.graphics.push("all")
	love.graphics.setColor(a, a, a, a)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(self.yi.composition.shared_layer_canvas)
	love.graphics.pop()
end

function MainMenu:handleKeyDown(key)
	if key == "return" then
		self.yi.composition:setScreen(self.yi.composition.select)
	elseif key == "m" then
		self.yi.composition:setScreen(self.yi.composition.multiplayer)
	elseif key == "c" then
		self.yi.composition:setScreen(self.yi.composition.config)
	end
end

return MainMenu
