local View = require("gui.View")
local NineSlice = require("gui.NineSlice")
local TrackContainer = require("gui.layout.TrackContainer")
local FlowContainer = require("gui.layout.FlowContainer")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local ChartInfo = require("ui.screens.song_select_v2.ChartInfo")
local ChartCarousel = require("ui.screens.song_select_v2.ChartCarousel")
local ChartList = require("ui.screens.song_select_v2.ChartList")
local Loading = require("ui.screens.chart_loading.Loading")
local Label = require("ui.views.Label")
local Button = require("ui.views.Button")

---@class ui.screens.song_select_v2.ChartBrowser : gui.View
---@operator call: ui.screens.song_select_v2.ChartBrowser
---@field content gui.layout.TrackContainer
---@field list gui.View The carousel, or the chart list while the sets are ungrouped.
---@field ungrouped boolean? What the list was built for.
---@field chart_info ui.screens.song_select_v2.ChartInfo
---@field loading ui.screens.chart_loading.Loading
---@field empty ui.views.Label
---@field no_results ui.views.Label
---@field clear_filters ui.views.Button
---@field download ui.views.Button
---@field charts rizu.api.Charts
---@field has_chartfiles boolean?
---@field has_chartfiles_checking boolean
---@field empty_state_dirty boolean
---@field refresh_notice gui.layout.FlowContainer
local ChartBrowser = View + {}

---Replaces the list when the sets turn grouped or ungrouped.
---@param settings rizu.config.Config
---@param localization ui.localization.Localization
function ChartBrowser:buildList(settings, localization)
	local ungrouped = self.charts:isUngrouped()
	if ungrouped == self.ungrouped then
		return
	end
	self.ungrouped = ungrouped
	if self.list then
		self.content:remove(self.list)
	end
	local List = ungrouped and ChartList or ChartCarousel
	self.list = self.content:add(List(self.charts, settings, localization), "*")
end

---@param ui ui.UserInterface
---@param charts rizu.api.Charts
---@param settings rizu.config.Config
---@param localization ui.localization.Localization
---@param on_filters_cleared fun()
function ChartBrowser:new(ui, charts, settings, localization, on_filters_cleared)
	View.new(self)

	local content = self:add(TrackContainer({
		direction = "column",
		gap = 10,
	}))
	content:anchorFill(0, 0, 0, 0)
	self.chart_info = content:add(ChartInfo(), ChartInfo.HEIGHT)
	self.content = content
	self.charts = charts
	self:buildList(settings, localization)

	self.has_chartfiles = nil
	self.has_chartfiles_checking = false
	self.empty_state_dirty = true
	self.empty = self:add(Label({
		font_name = "regular",
		font_size = 20,
		text = "You don't have any charts installed.",
		color = Colors.muted,
		align = "center",
	}))
	self.empty:setSize(500, 30):setAlignment(0.5, 0.5):addPosition(0, 30):setVisible(false)
	self.localization = localization
	self.no_results_text = "No charts found. Check your search and filters."
	self.no_results = self:add(Label({
		font_name = "regular",
		font_size = 20,
		text = self.no_results_text,
		color = Colors.muted,
		align = "center",
	}))
	self.no_results:setSize(500, 30):setAlignment(0.5, 0.5):addPosition(0, 30):setVisible(false)
	self.clear_filters = self:add(Button("Clear search and filters", function()
		charts:setSearch("")
		charts:clearFilters()
		on_filters_cleared()
		charts:selectCollection(nil)
	end, {variant = "primary", shape = "capsule", font_name = "medium", font_size = 18}))
	self.clear_filters:setSize(260, 44):setAlignment(0.5, 0.5):addPosition(0, 78):setVisible(false)
	self.download = self:add(Button("Download charts", function()
		ui:setScreen(ui.dlc, true)
	end, {variant = "primary", shape = "capsule", font_name = "medium", font_size = 18}))
	self.download:setSize(200, 44):setAlignment(0.5, 0.5):addPosition(0, 78):setVisible(false)

	local refresh_button = Button(localization:get("song_select.refresh"), function()
		self.refresh_notice:setVisible(false)
		charts:refresh()
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
	charts:on("library_changed", function()
		self.has_chartfiles = true
		self.empty_state_dirty = true
		self.refresh_notice:setVisible(true)
	end)

	self.loading = self:add(Loading())
	self.loading:setAlignment(0.5, 0.5):addPosition(0, 60):setOpacity(0)
	charts:on("sets_loading", function()
		self.empty_state_dirty = true
		self.list:fadeOut(0.1, "OutQuad")
		self.loading:fadeIn(0.1, "OutQuad")
	end)
	charts:on("sets_changed", function()
		self.empty_state_dirty = true
		self:buildList(settings, localization)
		self.list:fadeIn(0.1, "OutQuad")
		self.loading:fadeOut(0.1, "OutQuad")
	end)
end

function ChartBrowser:update()
	if not self.empty_state_dirty then return end
	self.empty_state_dirty = false

	local charts = self.charts
	local show_empty_state = not charts:isLoading() and charts:getSetCount() == 0
	local online = charts:getSource() == "online"
	if self.has_chartfiles == nil and show_empty_state and not online and not self.has_chartfiles_checking then
		self.has_chartfiles_checking = true
		charts:checkLibraryEmpty(function(empty)
			self.has_chartfiles = not empty
			self.has_chartfiles_checking = false
			self.empty_state_dirty = true
		end)
	end

	local has_chartfiles = self.has_chartfiles == true or online
	local online_error = online and charts:getOnlineError()
	self.no_results:setText(online_error
		and self.localization:get("song_select.online_error", {error = online_error})
		or self.no_results_text)
	local library_empty = self.has_chartfiles == false and not online
	self.empty:setVisible(show_empty_state and library_empty)
	self.no_results:setVisible(show_empty_state and has_chartfiles)
	self.clear_filters:setVisible(show_empty_state and has_chartfiles and not online_error)
	self.download:setVisible(show_empty_state and library_empty)
end

return ChartBrowser
