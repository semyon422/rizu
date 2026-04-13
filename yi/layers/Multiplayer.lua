local Layer = require("yi.Layer")
local composition = require("ui.composition")
local UIFactory = require("yi.UIFactory")
local Colors = require("yi.Colors")
local WireframeGlobe = require("yi.views.WireframeGlobe")

---@class yi.Multiplayer : yi.Layer
---@operator call: yi.Multiplayer
local Multiplayer = Layer + {}

---@param yi yi.UserInterface
function Multiplayer:new(yi)
	Layer.new(self)
	self.yi = yi

	local ui = UIFactory(yi.resources)
	self.globe = WireframeGlobe({
		width = 820,
		height = 820,
		color = Colors.cyan_200,
		alpha = 0.35,
		back_alpha = 0.04,
		line_width = 4,
		rotation_speed_x = 0.04,
		rotation_speed_y = 0.22,
	})
	self.globe:setPosition(0, -30)
	self.globe:setPivot(0.5, 0.5)

	self.composition_root = composition.Stack({
		self.globe,
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
