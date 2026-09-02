local View = require("gui.View")
local TrackContainer = require("gui.layout.TrackContainer")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Sounds = require("ui.Sounds")
local Line = require("ui.views.Line")
local Panel = require("ui.views.Panel")
local ChartSets = require("ui.screens.song_select.ChartSets")
local ChartGrid = require("ui.screens.song_select.ChartGrid")

---@class ui.screens.song_select.ChartBrowser.ChevronButton : gui.View
---@operator call: ui.screens.song_select.ChartBrowser.ChevronButton
local ChevronButton = View + {}

---@param sprite gui.Sprite
---@param on_click fun()
function ChevronButton:new(sprite, on_click)
	View.new(self)
	self.sprite = sprite
	self.on_click = on_click
	self.handles_mouse_input = true
end

function ChevronButton:onMouseClick(e)
	if e.button == 1 then
		self.on_click()
		return true
	end
end

function ChevronButton:draw()
	Painter.setColorTable(self.mouse_over and Colors.surface_raised or Colors.surface)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	local icon_width, icon_height = self.sprite:getDimensions()
	Painter.setColorTable(Colors.muted)
	self.sprite:draw((self.width - icon_width) / 2, (self.height - icon_height) / 2)
end

---@class ui.screens.song_select.ChartBrowser : gui.View
---@operator call: ui.screens.song_select.ChartBrowser
---@field chart_sets ui.screens.song_select.ChartSets
---@field chart_grid ui.screens.song_select.ChartGrid
local ChartBrowser = View + {}

---@param chart_selector rizu.select.ChartSelector
---@param settings rizu.config.Config
function ChartBrowser:new(chart_selector, settings)
	View.new(self)

	self:add(Panel({
		color = Colors.panel,
		line_color = Colors.outline,
	})):anchorFill(0, 0, 0, 0)

	local content = self:add(TrackContainer({
		direction = "column",
		padding = 6,
	}))
	content:anchorFill(0, 0, 0, 0)
	local difficulty_strip = content:add(TrackContainer({
		direction = "row",
		gap = 5,
		padding = {0, 0, 0, 12},
	}), 78)
	local function moveDifficulty(offset)
		chart_selector:scrollLevel(2, offset)
		Sounds.play("chart_changed")
		self.chart_grid:scrollToSelected()
	end
	difficulty_strip:add(ChevronButton(Resources.sprites.icon_chevron_left, function()
		moveDifficulty(-1)
	end), 38)
	self.chart_grid = difficulty_strip:add(ChartGrid(chart_selector), "*")
	difficulty_strip:add(ChevronButton(Resources.sprites.icon_chevron_right, function()
		moveDifficulty(1)
	end), 38)

	self.chart_sets = ChartSets(chart_selector, settings, function() end)
	content:add(self.chart_sets, "*")

	local divider = self:add(Line({color = Colors.divider}))
	divider:anchorFixed(6, 84, 0, 0)
	divider:fillWidth(6, 6)
end

return ChartBrowser
