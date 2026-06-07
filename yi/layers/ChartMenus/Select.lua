local Screen = require("yi.Screen")
local S = require("gui.composition.Strategies")
local UIFactory = require("yi.UIFactory")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")

local ChartInfo = require("yi.views.info.ChartInfo")
local ChartDifficulty = require("yi.views.info.ChartDifficulty")
local GameplayState = require("yi.views.info.GameplayState")
local IconButton = require("yi.views.IconButton")
local ChartList = require("yi.views.select.ChartList")
local SpringValue = require("gui.anim.SpringValue")

local ChartPreviewView = require("sphere.views.SelectView.ChartPreviewView")

---@class yi.Select : yi.Screen
---@overload fun(yi: yi.UserInterface): yi.Select
local Select = Screen + {}

local GAP = 20

---@param yi yi.UserInterface
function Select:new(yi)
	Screen.new(self)
	self.yi = yi

	local ui = UIFactory()

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

	self.chart_info = ChartInfo()
	self.chart_diff = ChartDifficulty(yi)
	self.gameplay_state = GameplayState()
	self.gameplay_state.y = -9
	self.chart_list = ChartList(self.yi.game.chartSelector)

	self.chart_preview_view = ChartPreviewView(yi.game)

	self.zoom = SpringValue({value = 1})

	local button_back = function()
		self.yi:setScreen("main_menu")
	end

	local button_config = function()
		self.yi:setScreen("config")
	end

	self.root = S.Stack({
		S.Track({
			space = {"*", 2, 64},
			S.Stack({
				ui:Image({
					image = "select_bg_gradient",
					fit_box = true,
					color = Colors.select_bg_gradient
				}),
				self.chart_list
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
				S.Stack({
					padding = {0, 10, 10, 0},
					S.Track({
						direction = "column",
						gap = 10,
						align = 0.5,
						IconButton(Resources.quads.icon_note),
						IconButton(Resources.quads.icon_folder),
						IconButton(Resources.quads.icon_download),
						ui:Rectangle({
							width = 64,
							height = 2,
							fit_box = false,
							color = Colors.line
						}),
						IconButton(Resources.quads.icon_gear, button_config),
						IconButton(Resources.quads.icon_funnel),
						IconButton(Resources.quads.icon_sparkles),
						IconButton(Resources.quads.icon_keyboard),
						IconButton(Resources.quads.icon_palette),
					}),
					S.Anchor({
						pivot = {0.5, 1},
						IconButton(Resources.quads.icon_chevron_left, button_back),
					})
				})
			})
		}),
		S.Stack({
			padding = GAP,
			S.Column({
				gap = -5,
				self.title,
				self.artist,
			}),
			S.Anchor({
				pivot = {0, 1},
				S.Flow({
					direction = "column",
					gap = 10,
					S.Flow({
						direction = "row",
						gap = 20,
						align = 1,
						self.chart_diff,
						ui:Rectangle({
							width = 3,
							height = 80,
							fit_box = false,
							color = Colors.line,
							blend_mode = "add"
						}),
						self.gameplay_state
					}),
					ui:Rectangle({
						width = 900,
						height = 3,
						fit_box = false,
						color = Colors.line,
						blend_mode = "add"
					}),
					self.chart_info
				}),
			})
		}),
	})

	local cv = self.yi.game.chartSelector.chartview
	if cv then
		self:onChartviewUpdate(cv)
	end

	self.gameplay_state:bind(self.yi.game.replayBase)
end

function Select:load()
	Screen.load(self)
	self.chart_preview_view:load()
	self.yi.game.chartSelector.onChanged:add(self)
end

function Select:unload()
	self.yi.game.chartSelector.onChanged:remove(self)
end

function Select:update(dt)
	self.chart_preview_view:update(dt)
	Screen.update(self, dt)
end

function Select:draw()
	love.graphics.push("all")
	self.chart_preview_view:draw()
	love.graphics.pop()
	Screen.draw(self)
end

---@param cv rizu.library.Chartview
function Select:onChartviewUpdate(cv)
	if not cv.hash then
		return
	end
	self.chart_info:bind(cv, self.yi.game.replayBase)
	self.chart_diff:bind(cv)
	self.title:setText(cv.title or "")
	self.artist:setText(cv.artist or "")
end

function Select:handleKeyDown(key)
	if key == "escape" then
		self.yi:setScreen("main_menu")
	elseif key == "return" then
		self.yi:setScreen("chart_loading")
	elseif key == "c" then
		self.yi:setScreen("config")
	elseif key == "j" then
		self.yi.game.chartSelector:scrollLevel(1, 1)
	elseif key == "k" then
		self.yi.game.chartSelector:scrollLevel(1, -1)
	elseif key == "h" then
		self.yi.game.chartSelector:scrollLevel(2, -1)
	elseif key == "l" then
		self.yi.game.chartSelector:scrollLevel(2, 1)
	else
		return false
	end

	return true
end

function Select:receive(event)
	if event.type == "chartview" then
		self:onChartviewUpdate(event.chartview)
		return
	end

	self.chart_preview_view:receive(event)
	Screen.receive(self, event)
end

return Select
