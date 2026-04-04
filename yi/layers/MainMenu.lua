local Layer = require("ui.Layer")
local Layout = require("ui.layout.Layout")
local UIFactory = require("yi.UIFactory")
local MainMenuWave = require("yi.views.MainMenuWave")

---@class yi.MainMenu : ui.Layer
---@operator call: yi.MainMenu
local MainMenu = Layer + {}

---@param yi yi.UserInterface
function MainMenu:new(yi)
	Layer.new(self)
	self.yi = yi

	self.layout = Layout({
		target_height = 1080,
		root = {id = "root"}
	})

	local ui = UIFactory(yi.resources)
	self.wave = MainMenuWave(yi.resources)

	self:addArray({
		self.wave,
		ui:Image({
			image = "rizu",
			box = self.layout:get("root"),
			scale_x = 0.7,
			scale_y = 0.7,
			anchor = {0.5, 0.5},
			origin = {0.5, 0.5},
		}),
		ui:Label({
			y = -4,
			anchor = {0.5, 1},
			origin = {0.5, 1},
			font_size = 24,
			font = "regular",
			text = "[Enter] Play [M] Multiplayer [C] Config",
		})
	})

end

function MainMenu:receive(event)
	if event.name ~= "keypressed" then
		return
	end

	local key = event[1] ---@type string

	if key == "enter" then
		self.yi:transitTo("select")
	elseif key == "m" then
		self.yi:transitTo("multiplayer")
	elseif key == "c" then
		self.yi:transitTo("config")
	end
end

return MainMenu
