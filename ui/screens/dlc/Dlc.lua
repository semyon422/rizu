local Button = require("ui.views.Button")
local DlcList = require("ui.screens.dlc.DlcList")
local DlcPanel = require("ui.screens.dlc.DlcPanel")
local DlcQueue = require("ui.screens.dlc.DlcQueue")
local Colors = require("ui.Colors")
local ContentTypeTab = require("ui.screens.dlc.ContentTypeTab")
local FlowContainer = require("gui.layout.FlowContainer")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local Loading = require("ui.screens.chart_loading.Loading")
local Panel = require("ui.views.Panel")
local Resources = require("ui.Resources")
local Screen = require("gui.Screen")
local SegmentedControl = require("ui.views.form.SegmentedControl")
local SidebarItem = require("ui.screens.dlc.SidebarItem")
local Textbox = require("ui.views.Textbox")
local ThumbnailCache = require("ui.screens.dlc.ThumbnailCache")
local UiActions = require("ui.UiActions")
local View = require("gui.View")
local delay = require("delay")
local thread = require("thread")

---@class ui.screens.dlc.Dlc : gui.Screen
---@operator call: ui.screens.dlc.Dlc
local Dlc = Screen + {}

local SEARCH_DEBOUNCE = 0.35

local content_types = {
	{key = "set", label = "osu! beatmaps"},
	{key = "pack", label = "Etterna packs"},
	{key = "skin", label = "Skins"},
}

local osu_statuses = {"any", "ranked", "qualified", "pending", "graveyard"}

local osu_status_labels = {
	any = "All",
	ranked = "Ranked",
	qualified = "Qualified",
	pending = "Pending",
	graveyard = "Graveyard",
}

local providers = {
	set = {
		{key = "mino", label = "Mino"},
		{key = "beatconnect", label = "BeatConnect"},
		{key = "akatsuki", label = "Akatsuki"},
		{key = "ripple", label = "Ripple"},
	},
	pack = {{key = "etterna", label = "EtternaOnline"}},
	skin = {},
}

---@param ui ui.UserInterface
function Dlc:new(ui)
	Screen.new(self)
	self.ui = ui
	self.content_type = "set"
	self.provider = "mino"
	self.page = 1
	self.query = ""
	self.status_filter = "ranked"
	self.search_generation = 0
	self.searching = false

	self.thumbnail_cache = ThumbnailCache(function(url)
		return ui.game.backgroundModel:loadImage(url, "http")
	end, 100)

	self.header = self.root:add(Panel({color = Colors.surface, line_color = Colors.outline, lines = {bottom = true}}))
	self.header:anchorFixed(0, 0, 1920, 106):fillWidth(0, 0)
	self.title = self.root:add(Label({font_name = "bold", font_size = 42, text = "Downloadable content"}))
	self.title:setPosition(40, 20)
	self.status = self.root:add(Label({font_name = "regular", font_size = 16, text = ""}))
	self.status:setPosition(40, 72)

	self.toolbar = self.root:add(View())
	self.toolbar:anchorFixed(0, 106, 1920, 68):fillWidth(0, 0)
	self.toolbar:add(Panel({
		color = Colors.panel,
		line_color = Colors.outline,
		lines = {bottom = true},
	})):anchorFill(0, 0, 0, 0)
	self.toolbar:add(Image(
		Resources.sprites.song_select_library_toolbar_shadow,
		"fit",
		{Colors.shadow[1], Colors.shadow[2], Colors.shadow[3], 0.27}
	)):anchorFill(0, 0, 0, 0)
	self.type_tabs = self.toolbar:add(FlowContainer({direction = "row", gap = 4, align = 0.5}))
	self.type_tabs:setPosition(40, 12)

	self.sidebar = self.root:add(View())
	self.sidebar:setWidth(240):fillHeight(190, 82):addPosition(40, 0)
	self.list_host = self.root:add(View())
	self.list_host:anchorFill(318, 190, 390, 82)
	self.list_host:add(DlcPanel(Colors.panel)):anchorFill(0, 0, 0, 0)
	self.list = self.list_host:add(DlcList(
		self.thumbnail_cache,
		function(item) self:download(item) end,
		function(item) return ui.game.dlcManager.tasks[item.id] end
	))
	self.list:anchorFill(8, 8, 8, 8)
	self.loading = self.list_host:add(Loading())
	self.loading:setAlignment(0.5, 0.5):setVisible(false)
	self.queue_title = self.root:add(Label({font_name = "bold", font_size = 20, text = "Download queue"}))
	self.queue_title:setSize(310, 28):setAlignment(1, 0):setOffset(-40, 190)
	self.queue_panel = self.root:add(DlcPanel(Colors.panel))
	self.queue_panel:setWidth(310):fillHeight(230, 82):setAlignmentX(1):setOffset(-40, 0)
	self.queue = self.root:add(DlcQueue())
	self.queue:setWidth(310):fillHeight(230, 82):setAlignmentX(1):setOffset(-40, 0)

	self.search = self.toolbar:add(Textbox({
		placeholder = "Search downloadable content...",
		on_change = function(text)
			self.query = text
			self.page = 1
			self.page_label:setText("Page 1")
			self:debounceSearch()
		end,
	}))
	self.search:setSize(620, 44):setPosition(446, 12)
	self.status_control = self.toolbar:add(SegmentedControl({
		label = "",
		options = osu_statuses,
		value = self.status_filter,
		format = function(value) return osu_status_labels[value] end,
		compact = true,
		on_change = function(value) self:setStatusFilter(value) end,
	}))
	self.status_control:setPosition(1090, 14)

	self.back = self.root:add(Button("Back", function() ui:setScreen(ui.main_menu, true) end, {
		variant = "secondary", font_name = "medium", font_size = 18,
	}))
	self.back:setSize(150, 44):setAlignment(0, 1):setOffset(40, -24)

	self.pagination = self.root:add(FlowContainer({direction = "row", gap = 12, align = 0.5}))
	self.previous = self.pagination:add(Button("Previous", function() self:setPage(self.page - 1) end, {
		variant = "secondary", font_name = "medium", font_size = 16,
	}))
	self.previous:setSize(120, 44)
	self.page_label = self.pagination:add(Label({font_name = "medium", font_size = 17, text = "Page 1", align = "center"}))
	self.page_label:setSize(100, 30)
	self.next = self.pagination:add(Button("Next", function() self:setPage(self.page + 1) end, {
		variant = "secondary", font_name = "medium", font_size = 16,
	}))
	self.next:setSize(120, 44)
	self.pagination:fitContent():setAlignment(0.5, 1):setOffset(0, -24)
	self:rebuildSidebar()
	self:refreshQueue()
end

function Dlc:refreshQueue()
	local tasks = {}
	for _, task in pairs(self.ui.game.dlcManager.tasks) do tasks[#tasks + 1] = task end
	table.sort(tasks, function(a, b) return tostring(a.id) < tostring(b.id) end)
	self.queue:setTasks(tasks)
end

function Dlc:rebuildSidebar()
	self.type_tabs:clear()
	for _, item in ipairs(content_types) do
		local key = item.key
		local tab = self.type_tabs:add(ContentTypeTab(item.label, function() self:setContentType(key) end))
		tab:setSelected(key == self.content_type)
	end
	self.type_tabs:fitContent()
	self.status_control:setVisible(self.content_type == "set")

	self.sidebar:clear()
	local provider_title = self.sidebar:add(Label({font_name = "bold", font_size = 16, text = "PROVIDER"}))
	provider_title:setPosition(12, 0)
	local choices = providers[self.content_type]
	if #choices > 0 then
		local provider_panel = self.sidebar:add(DlcPanel(Colors.panel))
		provider_panel:setSize(240, #choices * 49 - 5):setPosition(0, 32)
	end
	local provider_list = self.sidebar:add(FlowContainer({direction = "column", gap = 5}))
	provider_list:setPosition(0, 32)
	for _, item in ipairs(choices) do
		local key = item.key
		local button = provider_list:add(SidebarItem(item.label, function() self:setProvider(key) end))
		button:setSelected(key == self.provider)
	end
	provider_list:fitContent()
end

function Dlc:cancelPendingSearch()
	if not self.cancel_search_debounce then return end
	self.cancel_search_debounce()
	self.cancel_search_debounce = nil
end

function Dlc:debounceSearch()
	-- Invalidate an in-flight request as soon as its query becomes stale.
	self.search_generation = self.search_generation + 1
	local cancel = delay.debounce(self, "search_debounce", SEARCH_DEBOUNCE, self.searchContent, self)
	if cancel then self.cancel_search_debounce = cancel end
end

---@param content_type string
function Dlc:setContentType(content_type)
	if self.content_type == content_type then return end
	self.content_type = content_type
	self.page = 1
	self.page_label:setText("Page 1")
	local choices = providers[content_type]
	self.provider = choices[1] and choices[1].key or ""
	self:rebuildSidebar()
	self:cancelPendingSearch()
	self:searchContent()
end

---@param provider string
function Dlc:setProvider(provider)
	if self.provider == provider then return end
	self.provider = provider
	self.page = 1
	self.page_label:setText("Page 1")
	self:rebuildSidebar()
	self:cancelPendingSearch()
	self:searchContent()
end

---@param status string
function Dlc:setStatusFilter(status)
	if self.status_filter == status then return end
	self.status_filter = status
	self.page = 1
	self.page_label:setText("Page 1")
	self:cancelPendingSearch()
	self:searchContent()
end

---@param page integer
function Dlc:setPage(page)
	if page < 1 or page == self.page then return end
	self.page = page
	self.page_label:setText("Page " .. page)
	self:cancelPendingSearch()
	self:searchContent()
end

function Dlc:searchContent()
	self.cancel_search_debounce = nil
	self.search_generation = self.search_generation + 1
	local generation = self.search_generation
	if self.content_type == "skin" then
		self.searching = false
		self.loading:setVisible(false)
		self.list:setVisible(true)
		self.list:setItems({})
		self.status:setText("No skin provider is available yet.")
		return
	end
	self.searching = true
	self.list:setVisible(false)
	self.loading:setVisible(true)
	self.status:setText("Searching " .. self.provider .. "...")
	local query, page, provider = self.query, self.page, self.provider
	local status = self.status_filter
	if status == "any" and provider ~= "mino" then status = "all" end
	thread.coro(function()
		local results, err = self.ui.game.dlcManager:search(query, {page = page, status = status}, provider)
		if generation ~= self.search_generation then return end
		self.searching = false
		self.loading:setVisible(false)
		self.list:setVisible(true)
		if not results then
			self.list:setItems({})
			self.status:setText("Search failed: " .. tostring(err))
			return
		end
		self.list:setItems(results)
		self.status:setText(("%d result%s from %s"):format(#results, #results == 1 and "" or "s", provider))
	end)()
end

---@param item table
function Dlc:download(item)
	if not item.id then return end
	self.ui.game.dlcManager:download(item.id, self.content_type, self.provider, item)
	self.status:setText("Download queued: " .. tostring(item.title or item.name or item.id))
end

function Dlc:enter()
	self.task_observer = self.task_observer or self.ui.game.dlcManager.onTaskUpdated:add(function()
		self:refreshQueue()
	end)
	self:refreshQueue()
	self.root:setOpacity(0):fadeIn(0.3, "OutQuint")
	if #self.list.items == 0 then self:searchContent() end
end

function Dlc:exit()
	self:cancelPendingSearch()
	self.searching = false
	self.loading:setVisible(false)
	self.search_generation = self.search_generation + 1
	if self.task_observer then
		self.ui.game.dlcManager.onTaskUpdated:remove(self.task_observer)
		self.task_observer = nil
	end
	Screen.exit(self)
	self.root:fadeOut(0.2, "OutQuad")
	return true
end

function Dlc:unload()
	self:cancelPendingSearch()
	if self.task_observer then
		self.ui.game.dlcManager.onTaskUpdated:remove(self.task_observer)
		self.task_observer = nil
	end
	self.thumbnail_cache:clear()
	Screen.unload(self)
end

---@param inputs gui.Inputs
function Dlc:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.main_menu, true)
	end
end

return Dlc
