local Screen = require("gui.Screen")
local S = require("gui.composition.Strategies")
local Colors = require("yi.Colors")
local Rectangle = require("yi.views.Rectangle")

---@class yi.layers.Select: gui.Screen
---@operator call: yi.layers.Select
local Select = Screen + {}

---@param ui yi.UserInterface
function Select:new(ui)
	Screen.new(self)
	self.ui = ui

	self.root = S.Stack({
		S.Track({
			direction = "column",
			space = {70, 2, "*", 2, 70},

			Rectangle({color = Colors.panel}),
			Rectangle({color = Colors.outline}),
			S.Stack({
				padding = {0, 20, 20, 0},
				S.Track({
					direction = "row",
					space = {"*", -0.44, "*", -0.46, "*"},
					S.Stack(), -- Left gap
					self:createLeftColumn(),
					S.Stack(), -- Center gap
					self:createRightColumn(),
					S.Stack() -- Right gap
				}),
			}),
			Rectangle({color = Colors.outline}),
			Rectangle({color = Colors.panel}),
		})
	})
end

function Select:createLeftColumn()
	return S.Track({
		direction = "column",
		space = {469, "*", 400},
		Rectangle({color = Colors.panel}),
		S.Stack(),
		Rectangle({color = Colors.panel})
	})
end

function Select:createRightColumn()
	return S.Track({
		direction = "column",
		space = {28, 57, 64, 22, 136, 22, 562},

		Rectangle({color = Colors.panel}),
		S.Stack(),
		Rectangle({color = Colors.panel}),
		S.Stack(),
		Rectangle({color = Colors.panel}),
		S.Stack(),
		Rectangle({color = Colors.panel}),
	})
end

function Select:handleKeyDown(key)
	if key == "return" then
		self.ui:setScreen("gameplay")
	end
end

return Select
