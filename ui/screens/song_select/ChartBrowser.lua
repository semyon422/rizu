local View = require("gui.View")
local NineSlice = require("gui.NineSlice")
local TrackContainer = require("gui.layout.TrackContainer")
local FlowContainer = require("gui.layout.FlowContainer")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Sounds = require("ui.Sounds")
local Line = require("ui.views.Line")
local ChartSets = require("ui.screens.song_select.ChartSets")
local ChartGrid = require("ui.screens.song_select.ChartGrid")
local Loading = require("ui.screens.chart_loading.Loading")
local Label = require("ui.views.Label")
local Button = require("ui.views.Button")
local thread = require("thread")

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
	Resources.sprites.song_select_chevron:draw(0, 0)
	local icon_width, icon_height = self.sprite:getDimensions()
	Painter.setColorTable(Colors.muted)
	self.sprite:draw((self.width - icon_width) / 2, (self.height - icon_height) / 2)
end

---@class ui.screens.song_select.ChartBrowser : gui.View
---@operator call: ui.screens.song_select.ChartBrowser
---@field chart_sets ui.screens.song_select.ChartSets
---@field chart_grid ui.screens.song_select.ChartGrid
---@field loading ui.screens.chart_loading.Loading
---@field empty ui.views.Label
---@field no_results ui.views.Label
---@field clear_filters ui.views.Button
---@field download ui.views.Button
---@field chart_selector rizu.select.ChartSelector
---@field has_chartfiles boolean?
---@field has_chartfiles_checking boolean
---@field primary_items_loading boolean
---@field empty_state_dirty boolean
---@field refresh_notice gui.layout.FlowContainer
local ChartBrowser = View + {}

---@param ui ui.UserInterface
---@param chart_selector rizu.select.ChartSelector
---@param settings rizu.config.Config
---@param tooltip ui.views.Tooltip?
---@param localization ui.localization.Localization
function ChartBrowser:new(ui, chart_selector, settings, tooltip, localization)
	View.new(self)

	self:add(NineSlice(Resources.nine_slices.song_select_panel, nil, true)):anchorFill(0, 0, 0, 0)

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
	self.chart_grid = difficulty_strip:add(ChartGrid(chart_selector, tooltip, localization), "*")
	difficulty_strip:add(ChevronButton(Resources.sprites.icon_chevron_right, function()
		moveDifficulty(1)
	end), 38)

	self.chart_sets = ChartSets(chart_selector, settings, function() end)
	content:add(self.chart_sets, "*")

	self.chart_selector = chart_selector
	self.has_chartfiles = nil
	self.has_chartfiles_checking = false
	self.primary_items_loading = false
	self.empty_state_dirty = true
	self.empty = self:add(Label({
		font_name = "regular",
		font_size = 20,
		text = "You don't have any charts installed.",
		color = Colors.muted,
		align = "center",
	}))
	self.empty:setSize(500, 30):setAlignment(0.5, 0.5):addPosition(0, 30):setVisible(false)
	self.no_results = self:add(Label({
		font_name = "regular",
		font_size = 20,
		text = "No charts found. Check your search and filters.",
		color = Colors.muted,
		align = "center",
	}))
	self.no_results:setSize(500, 30):setAlignment(0.5, 0.5):addPosition(0, 30):setVisible(false)
	self.clear_filters = self:add(Button("Clear search and filters", function()
		chart_selector.searchModel:setSearchString("")
		chart_selector.filterModel:clearFilters()
		ui.song_select.library_toolbar.search:setText("")
		ui.game.collectionSelector:selectCollection(nil, nil)
	end, {variant = "primary", shape = "capsule", font_name = "medium", font_size = 18}))
	self.clear_filters:setSize(260, 44):setAlignment(0.5, 0.5):addPosition(0, 78):setVisible(false)
	self.download = self:add(Button("Download charts", function()
		ui:setScreen(ui.dlc, true)
	end, {variant = "primary", shape = "capsule", font_name = "medium", font_size = 18}))
	self.download:setSize(200, 44):setAlignment(0.5, 0.5):addPosition(0, 78):setVisible(false)

	local refresh_button = Button(localization:get("song_select.refresh"), function()
		self.refresh_notice:setVisible(false)
		chart_selector:noDebounceRefresh()
	end, {variant = "success", shape = "capsule", font_name = "medium", font_size = 16})
	refresh_button:setSize(100, 34)
	self.refresh_notice = self:add(FlowContainer({
		direction = "row",
		gap = 10,
		align = 0.5,
		padding = {14, 10, 10, 10},
	}))
	local refresh_background = self.refresh_notice:add(NineSlice(Resources.nine_slices.song_select_refresh_notice, nil, true))
	refresh_background:setLayoutIgnore(true):anchorFill(0, 0, 0, 0)
	self.refresh_notice:add(Label({
		text = localization:get("song_select.new_songs"),
		font_name = "regular",
		font_size = 16,
		color = Colors.muted,
	}))
	self.refresh_notice:add(refresh_button)
	self.refresh_notice:anchorFixed(0, 0, 0, 0):setAlignment(1, 1)
	self.refresh_notice:fitContent():setVisible(false)
	chart_selector.library.onChartsChanged:add(function()
		self.has_chartfiles = true
		self.empty_state_dirty = true
		self.refresh_notice:setVisible(true)
	end)

	self.loading = self:add(Loading())
	self.loading:setAlignment(0.5, 0.5):addPosition(0, 60):setOpacity(0)
	chart_selector:onChanged(function(event)
		if event.type == "primary_items_loading" then
			self.primary_items_loading = true
			self.empty_state_dirty = true
			self.chart_sets:fadeOut(0.1, "OutQuad")
			self.chart_grid:fadeOut(0.1, "OutQuad")
			self.loading:fadeIn(0.1, "OutQuad")
		elseif event.type == "primary_items_updated" then
			self.primary_items_loading = false
			self.empty_state_dirty = true
			self.chart_sets:fadeIn(0.1, "OutQuad")
			self.chart_grid:fadeIn(0.1, "OutQuad")
			self.loading:fadeOut(0.1, "OutQuad")
		end
	end)

	local divider = self:add(Line({color = Colors.divider}))
	divider:anchorFixed(6, 84, 0, 0)
	divider:fillWidth(6, 6)
end

function ChartBrowser:update()
	if not self.empty_state_dirty then return end
	self.empty_state_dirty = false

	local has_items = self.chart_selector.stores[1]:count() > 0
	local show_empty_state = not self.primary_items_loading and not has_items
	if self.has_chartfiles == nil and show_empty_state and not self.has_chartfiles_checking then
		self.has_chartfiles_checking = true
		thread.coro(function()
			self.has_chartfiles = self.chart_selector.library:hasChartfilesAsync()
			self.has_chartfiles_checking = false
			self.empty_state_dirty = true
		end)()
	end

	local has_chartfiles = self.has_chartfiles == true
	self.empty:setVisible(show_empty_state and self.has_chartfiles == false)
	self.no_results:setVisible(show_empty_state and has_chartfiles)
	self.clear_filters:setVisible(show_empty_state and has_chartfiles)
	self.download:setVisible(show_empty_state and self.has_chartfiles == false)
end

return ChartBrowser
