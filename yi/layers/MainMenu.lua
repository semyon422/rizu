local Layer = require("ui.Layer")
local composition = require("ui.composition")
local UIFactory = require("yi.UIFactory")
local MainMenuWave = require("yi.views.MainMenuWave")

---@class yi.MainMenu : ui.Layer
---@operator call: yi.MainMenu
local MainMenu = Layer + {}

---@param yi yi.UserInterface
function MainMenu:new(yi)
	Layer.new(self)
	self.yi = yi

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

function MainMenu:receive(event)
	if event.name ~= "keypressed" then
		return
	end

	local key = event[1] ---@type string

	if key == "return" then
		self.yi:transitTo("select")
	elseif key == "m" then
		self.yi:transitTo("multiplayer")
	elseif key == "c" then
		self.yi:transitTo("config")
	end
end

return MainMenu
