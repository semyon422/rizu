local Screen = require("yi.Screen")
local S = require("ui.composition.Strategies")
local UIFactory = require("yi.UIFactory")
local Colors = require("yi.Colors")

local ChartInfo = require("yi.views.ChartInfo")

---@class yi.Select : yi.Screen
---@overload fun(yi: yi.UserInterface): yi.Select
local Select = Screen + {}

local GAP = 20

---@param yi yi.UserInterface
function Select:new(yi)
	Screen.new(self)
	self.yi = yi
	yi.game.chartSelector.onChanged:add(self)

	local ui = UIFactory(yi.resources)

	self.title = ui:Label({
		font = "bold",
		font_size = 72,
		text = "Artist",
		color = Colors.text_title,
	})

	self.artist = ui:Label({
		font = "bold",
		font_size = 46,
		text = "Title",
		color = Colors.text_subsection,
	})

	self.chart_info = ChartInfo(yi.resources)
	self.chart_info.pivot = {0, 1}

	self.composition:setRoot(S.Stack({
		ui:Image({
			image = "select_bg_gradient",
			mode = "stretch",
			color = Colors.slate_900_70
		}),
		S.Stack({
			padding = GAP,
			S.Column({
				gap = -10,
				self.title,
				self.artist,
			}),
			S.Anchor({
				pivot = {0, 1},
				self.chart_info
			})
		}),
	}))
end

function Select:handleKeyDown(key)
	if key == "escape" then
		self.yi.composition:setScreen(self.yi.composition.main_menu)
	elseif key == "c" then
		self.yi.composition:setScreen(self.yi.composition.config)
	end
end

function Select:receive(event)
	if event.type == "chartview" then
		local cv = event.chartview ---@type rizu.library.Chartview
		self.chart_info:bind(cv, self.yi.game.replayBase)
		self.title:setText(cv.title or "")
		self.artist:setText(cv.artist or "")
		return
	end

	Screen.receive(self, event)
end

return Select
