local Layer = require("yi.Layer")
local composition = require("ui.composition")
local UIFactory = require("yi.UIFactory")
local Colors = require("yi.Colors")

---@class yi.Select : yi.Layer
---@overload fun(yi: yi.UserInterface): yi.Select
local Select = Layer + {}

---@param yi yi.UserInterface
function Select:new(yi)
	Layer.new(self)
	self.yi = yi
	local ui = UIFactory(yi.resources)

	self.title = ui:Label({
		font = "bold",
		font_size = 72,
		text = "Artist",
	})

	self.artist = ui:Label({
		font = "bold",
		font_size = 46,
		text = "Title",
	})

	self.composition_root = composition.Stack({
		ui:Image({
			image = "select_bg_gradient",
			mode = "stretch",
			color = Colors.slate_900_70
		}),
		composition.Stack({
			padding = 20,
			composition.Vertical({
				gap = -16,
				self.title,
				self.artist,
			}),
		})
	})
end

function Select:handleKeyDown(key)
	if key == "escape" then
		self.yi:transitTo(self.yi.main_menu)
	elseif key == "c" then
		self.yi:transitTo(self.yi.config)
	end
end

return Select
