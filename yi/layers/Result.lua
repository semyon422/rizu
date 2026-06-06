local Layer = require("gui.Layer")
local S = require("gui.composition.Strategies")
local UIFactory = require("yi.UIFactory")
local Colors = require("yi.Colors")

---@class yi.layers.Result : gui.Layer
---@operator call: yi.layers.Result
local Result = Layer + {}

---@param yi yi.UserInterface
function Result:new(yi)
	Layer.new(self)
	self.yi = yi

	local ui = UIFactory()

	self.composition:setRoot(S.Stack({
		S.Track({
			space = {"*", 2, 64},
			S.Stack({
				ui:Image({
					image = "select_bg_gradient",
					fit_box = true,
					color = Colors.select_bg_gradient
				}),
			}),
			ui:Rectangle({
				fit_box = true,
				color = Colors.line
			}),
			S.Stack({
				ui:Rectangle({
					fit_box = true,
					color = Colors.select_side_panel_bg
				}),
			})
		}),
		S.Anchor({
			pivot = {0.5, 0.5},
			ui:Label({
				font = "bold",
				font_size = 72,
				text = "95.78%",
				color = Colors.text,
			}),
		})
	}))
end

function Result:handleKeyDown(key)
	if key == "escape" then
		self.yi:setScreen("select")
	elseif key == "c" then
		self.yi:setScreen("config")
	end
end

return Result
