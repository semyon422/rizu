local Screen = require("yi.Screen")
local composition = require("ui.composition")
local UIFactory = require("yi.UIFactory")

---@class yi.Multiplayer : yi.Screen
---@operator call: yi.Multiplayer
local Multiplayer = Screen + {}

---@param yi yi.UserInterface
function Multiplayer:new(yi)
	Screen.new(self)
	self.yi = yi

	local ui = UIFactory(yi.resources)

	self.composition_root = composition.Stack({
		ui:Label({
			y = -250,
			pivot = {0.5, 0.5},
			font_size = 46,
			font = "regular",
			text = "MULTIPLAYER",
		}),
		ui:Label({
			pivot = {0.5, 0.5},
			font_size = 72,
			font = "regular",
			text = "NOT CONNECTED",
		}),
		ui:Label({
			y = 238,
			pivot = {0.5, 0.5},
			font_size = 24,
			font = "regular",
			text = "[Esc] Back",
		}),
	})
end

function Multiplayer:handleKeyDown(key)
	if key == "escape" then
		self.yi:transitTo(self.yi.main_menu)
	end
end

return Multiplayer
