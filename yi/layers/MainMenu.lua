local Layer = require("gui.Layer")
local UIFactory = require("yi.UIFactory")
local S = require("gui.composition.Strategies")
local MainMenuWave = require("yi.views.MainMenuWave")

---@class yi.MainMenu : gui.Layer
---@operator call: yi.MainMenu
local MainMenu = Layer + {}

---@param yi yi.UserInterface
function MainMenu:new(yi)
	Layer.new(self)
	self.yi = yi

	local ui = UIFactory()

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
			}),
		}),
	}))
end

function MainMenu:handleKeyDown(key)
	if key == "return" then
		self.yi:setScreen("select")
	elseif key == "c" then
		self.yi:setScreen("config")
	end
end

return MainMenu
