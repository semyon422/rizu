local Layer = require("gui.Layer")
local S = require("gui.composition.Strategies")
local UIFactory = require("yi.UIFactory")
local Colors = require("yi.Colors")

local ChartInfo = require("yi.views.select.ChartInfo")
local IconButton = require("yi.views.IconButton")

---@class yi.Select : gui.Layer
---@overload fun(yi: yi.UserInterface): yi.Select
local Select = Layer + {}

local GAP = 20

---@param yi yi.UserInterface
function Select:new(yi)
	Layer.new(self)
	self.yi = yi
	yi.game.chartSelector.onChanged:add(self) -- TODO: REMOVE ON UNLOAD!!!!!!!!!!

	local ui = UIFactory(yi.resources)

	self.title = ui:Label({
		font = "bold",
		font_size = 72,
		text = "Artist",
		color = Colors.text,
	})

	self.artist = ui:Label({
		font = "bold",
		font_size = 46,
		text = "Title",
		color = Colors.text_muted,
	})

	self.chart_info = ChartInfo(yi.resources)
	self.chart_info.pivot = {0, 1}

	self.composition:setRoot(S.Stack({
		S.Track({
			space = {"*", 2, 64},
			ui:Image({
				image = "select_bg_gradient",
				fit_box = true,
				color = Colors.select_bg_gradient
			}),
			ui:Rectangle({
				fit_box = true,
				color = Colors.select_side_panel_line
			}),
			S.Stack({
				ui:Rectangle({
					fit_box = true,
					color = Colors.select_side_panel_bg
				}),
				S.Stack({
					padding = {0, 10, 10, 0},
					S.Track({
						space = {"-", "-", "-"},
						direction = "column",
						gap = 10,
						align = 0.5,
						IconButton(yi.resources, yi.resources.quads.icon_music),
						IconButton(yi.resources, yi.resources.quads.icon_folder),
						IconButton(yi.resources, yi.resources.quads.icon_download),
					}),
					S.Anchor({
						pivot = {0.5, 1},
						IconButton(yi.resources, yi.resources.quads.icon_download),
					})
				})
			})
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

	local cv = self.yi.game.chartSelector.chartview
	if cv then
		self:onChartviewUpdate(cv)
	end
end

---@param cv rizu.library.Chartview
function Select:onChartviewUpdate(cv)
	if not cv.hash then
		return
	end
	self.chart_info:bind(cv, self.yi.game.replayBase)
	self.title:setText(cv.title or "")
	self.artist:setText(cv.artist or "")
end

function Select:handleKeyDown(key)
	if key == "escape" then
		self.yi:setScreen("main_menu")
	elseif key == "return" then
		self.yi:setScreen("gameplay")
	elseif key == "c" then
		self.yi:setScreen("config")
	elseif key == "j" then
		self.yi.game.chartSelector:scrollLevel(1, -1)
	elseif key == "k" then
		self.yi.game.chartSelector:scrollLevel(1, 1)
	elseif key == "h" then
		self.yi.game.chartSelector:scrollLevel(2, -1)
	elseif key == "l" then
		self.yi.game.chartSelector:scrollLevel(2, 1)
	end
end

function Select:receive(event)
	if event.type == "chartview" then
		self:onChartviewUpdate(event.chartview)
		return
	end

	Layer.receive(self, event)
end

return Select
