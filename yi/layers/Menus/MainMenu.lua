local Screen = require("gui.Screen")
local UIFactory = require("yi.UIFactory")
local S = require("gui.composition.Strategies")
local MainMenuWave = require("yi.views.MainMenuWave")

---@class yi.MainMenu : gui.Screen
---@operator call: yi.MainMenu
local MainMenu = Screen + {}

---@param yi yi.UserInterface
function MainMenu:new(yi)
	Screen.new(self)
	self.yi = yi
	local ui = UIFactory()

	self.root = S.Stack({
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
			}),
		}),
	})
end

function MainMenu:handleKeyDown(key)
	if key == "c" then
		self.yi:setScreen("config")
	elseif key == "return" then
		self.yi:setScreen("select")
	else
		return false
	end

	return true
end

return MainMenu
