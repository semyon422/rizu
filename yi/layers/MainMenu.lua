local Layer = require("yi.Layer")
local composition = require("ui.composition")
local UIFactory = require("yi.UIFactory")
local MainMenuWave = require("yi.views.MainMenuWave")

---@class yi.MainMenu : yi.Layer
---@operator call: yi.MainMenu
local MainMenu = Layer + {}

---@param yi yi.UserInterface
function MainMenu:new(yi)
	Layer.new(self)
	self.yi = yi
	self.canvas = love.graphics.newCanvas(love.graphics.getDimensions())

	local ui = UIFactory(yi.resources)
	self.composition_root = composition.Stack({
		MainMenuWave(yi.resources),
		composition.Vertical({
			pivot = {0.5, 0.5},
			align = {0, 0.5},

			ui:Image({
				image = "rizu",
				scale_x = 0.7,
				scale_y = 0.7,
				pivot = {0.5, 0.5},
			}),
			ui:Label({
				y = -4,
				font_size = 24,
				font = "regular",
				text = "[Enter] Play [M] Multiplayer [C] Config",
			}),
		})
	})
end

function MainMenu:draw()
	local a = self.transition:get()

	love.graphics.setCanvas(self.canvas)
	love.graphics.clear()
	love.graphics.setBlendMode("alpha", "alphamultiply")
	Layer.draw(self)
	love.graphics.setCanvas()

	love.graphics.setColor(a, a, a, a)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(self.canvas)
	love.graphics.setBlendMode("alpha")
end

function MainMenu:handleKeyDown(key)
	if key == "return" then
		self.yi:transitTo(self.yi.select)
	elseif key == "m" then
		self.yi:transitTo(self.yi.multiplayer)
	elseif key == "c" then
		self.yi:transitTo(self.yi.config)
	end
end

return MainMenu
