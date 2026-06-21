local Screen = require("gui.Screen")
local S = require("gui.composition.Strategies")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local Rectangle = require("yi.views.Rectangle")
local Image = require("yi.views.Image")
local Label = require("yi.views.Label")
local BackgroundPanel = require("yi.views.select.BackgroundPanel")
local ScoreList = require("yi.views.select.ScoreList")
local ChartSets = require("yi.views.select.ChartSets")

---@class yi.layers.Select: gui.Screen
---@operator call: yi.layers.Select
local Select = Screen + {}

---@param ui yi.UserInterface
function Select:new(ui)
	Screen.new(self)
	self.ui = ui
	self.background_panel = BackgroundPanel(ui.game.backgroundModel)
	self.score_list = ScoreList(ui.game.scoreSelector, function(i) self:openScore(i) end)
	self.chart_sets = ChartSets(ui.game.chartSelector, function(i) end)

	self.root = S.Stack({
		S.Track({
			direction = "column",
			space = {70, 2, "*", 2, 70},

			self:createHeader(),
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

---@param index integer
function Select:openScore(index)
	self.ui.game.scoreSelector:scrollScore(nil, index)
	self.ui.game.resultController:replayNoteChartAsync("result", self.ui.game.scoreSelector.chartplay)
	self.ui:setScreen("result")
end

function Select:enter()
	self.ui.game.chartSelector.onChanged:add(self)
	self.ui.game.chartSelector.state.onChanged:add(self)
	self.ui.game.scoreSelector.onChanged:add(self)
	local cv = self.ui.game.chartSelector.chartview
	if cv then
		self:onChartviewUpdate(cv)
		self.score_list:reload()
	end
end

function Select:exit()
	self.ui.game.chartSelector.onChanged:remove(self)
	self.ui.game.chartSelector.state.onChanged:remove(self)
	self.ui.game.scoreSelector.onChanged:remove(self)
end

function Select:createLeftColumn()
	return S.Track({
		direction = "column",
		space = {469, "*", 400},
		self.background_panel,
		S.Stack(),
		self.score_list
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
		self.chart_sets
	})
end

function Select:createHeader()
	return S.Stack({
		Rectangle({color = Colors.panel}),
		S.Track({
			direction = "row",
			space = {"*", -0.44, "*", -0.46, "*"},

			S.Stack(),
			S.Anchor({
				pivot = {0, 0.5},

				S.Flow({
					direction = "row",
					align = 0.5,
					gap = 32,
					Image({quad = Resources.quads.rizu_small}),
					Label({font_name = "regular", font_size = 24, text = "Online: 1"})
				})
			}),
			S.Stack(),
			S.Stack(),
			S.Stack()
		})
	})
end

---@param cv rizu.library.LocatedChartview
function Select:onChartviewUpdate(cv)
	self.background_panel:bind(cv)
end

function Select:handleKeyDown(key)
	if key == "return" then
		self.ui:setScreen("gameplay")
	elseif key == "j" then
		self.ui.game.chartSelector:scrollLevel(1, 1)
	elseif key == "k" then
		self.ui.game.chartSelector:scrollLevel(1, -1)
	end
end

function Select:receive(event)
	Screen.receive(self, event)
	if event.type == "chartview" and event.chartview.hash then --- TODO: Why is this 'type' when it should be 'name'?
		self:onChartviewUpdate(event.chartview)
	end
	if event.type == "scores_loaded" then
		self.score_list:reload()
	end
end

return Select
