local Screen = require("yi.Screen")
local Title = require("yi.views.Title")

local ConfigList = require("yi.views.config_list.ConfigList")
local Colors = require("yi.Colors")
local UIFactory = require("yi.UIFactory")

local S = require("ui.composition.Strategies")

---@class yi.Config : yi.Screen
---@operator call: yi.Config
local Config = Screen + {}

---@param yi yi.UserInterface
function Config:new(yi)
	Screen.new(self)
	self.yi = yi

	self.atlas, self.quads = yi.resources.atlas, yi.resources.quads

	self.composition:setRoot(S.Stack({
		padding = {100, 60, 100, 60},

		S.Track({
			direction = "column",
			space = {120, 20, "*"},

			Title(self.atlas, self.quads),
			S.Stack(),
			S.Stack({
				padding = 20,

				S.Anchor({
					pivot = {0.5, 0},
					ConfigList(yi.resources)
				})
			})
		}),
	}))
end

function Config:draw()
	local a = self.transition:get()

	love.graphics.push("all")
	love.graphics.setCanvas(self.yi.composition.shared_layer_canvas)
	love.graphics.clear()
	Screen.draw(self)
	love.graphics.pop()

	love.graphics.push("all")
	love.graphics.setColor(a, a, a, a)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(self.yi.composition.shared_layer_canvas)
	love.graphics.pop()
end

function Config:handleKeyDown(key)
	if key == "escape" then
		self.yi.composition:setScreen(
			self.yi.composition.previous_screen or self.yi.composition.main_menu
		)
	end
end

return Config
