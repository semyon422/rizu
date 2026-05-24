local Screen = require("yi.Screen")
local Title = require("yi.views.Title")

local ConfigList = require("yi.views.config_list.ConfigList")
local ConfigTopBar = require("yi.views.config_list.ConfigTopBar")

local S = require("ui.composition.Strategies")

---@class yi.Config : yi.Screen
---@operator call: yi.Config
local Config = Screen + {}

---@param yi yi.UserInterface
function Config:new(yi)
	Screen.new(self)
	self.yi = yi

	self.atlas, self.quads = yi.resources.atlas, yi.resources.quads

	local config_list = ConfigList(yi.resources)
	local tabs = {"ALL", "AUDIO", "VIDEO", "UI", "GAMEPLAY"}
	self.top_bar = ConfigTopBar(yi.resources, tabs, function() end)

	self.composition:setRoot(S.Stack({
		padding = {100, 60, 60, 100},

		S.Track({
			direction = "column",
			space = {120, 20, 70, 20, "*"},

			Title(self.atlas, self.quads),
			S.Stack(),
			self.top_bar,
			S.Stack(),
			S.Stack({
				padding = 20,

				S.Anchor({
					pivot = {0.5, 0},
					config_list
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
		return true
	end

	if tonumber(key) then
		self.top_bar:setTabActive(tonumber(key))
	end
end

return Config
