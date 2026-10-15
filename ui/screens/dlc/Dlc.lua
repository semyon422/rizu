local Button = require("ui.views.Button")
local IconTextButton = require("ui.views.IconTextButton")
local DlcList = require("ui.screens.dlc.DlcList")
local DlcPanel = require("ui.screens.dlc.DlcPanel")
local DlcQueue = require("ui.screens.dlc.DlcQueue")
local Dropdown = require("ui.screens.song_select_v2.Dropdown")
local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local Loading = require("ui.screens.chart_loading.Loading")
local Panel = require("ui.views.Panel")
local PopupContainer = require("ui.views.PopupContainer")
local Resources = require("ui.Resources")
local Screen = require("gui.Screen")
local SidebarItem = require("ui.screens.dlc.SidebarItem")
local TrackContainer = require("gui.layout.TrackContainer")
local SearchField = require("ui.screens.song_select_v2.SearchField")
local Scrim = require("ui.screens.song_select_v2.Scrim")
local ThumbnailCache = require("ui.screens.dlc.ThumbnailCache")
local UiActions = require("ui.UiActions")
local View = require("gui.View")
local delay = require("delay")
local thread = require("thread")

---@class ui.screens.dlc.Dlc : gui.Screen
---@operator call: ui.screens.dlc.Dlc
local Dlc = Screen + {}

local SEARCH_DEBOUNCE = 0.35

-- Same translucent look as the song select header and panels, over a dark scrim.
local EDGE = 40
local TOOLBAR_TOP = 120
local TOOLBAR_HEIGHT = 54
local FOOTER_BOTTOM = 12
local HEADER_COLOR = {Colors.background[1], Colors.background[2], Colors.background[3], 0.55}
local HEADER_LINE_COLOR = {Colors.outline[1], Colors.outline[2], Colors.outline[3], 0.5}
local PAGE_LABEL_WIDTH = 100
local PANEL_COLOR = {Colors.background[1], Colors.background[2], Colors.background[3], 0.62}

local content_types = {
	{key = "set", label = "osu! beatmaps"},
	{key = "pack", label = "Etterna packs"},
	{key = "skin", label = "Skins"},
}

local osu_statuses = {"any", "ranked", "qualified", "pending", "graveyard"}

local osu_modes = {"any", "osu", "taiko", "catch", "mania"}

local osu_mode_labels = {
	any = "All modes",
	osu = "osu!",
	taiko = "Taiko",
	catch = "Catch",
	mania = "Mania",
}

local osu_status_labels = {
	any = "All",
	ranked = "Ranked",
	qualified = "Qualified",
	pending = "Pending",
	graveyard = "Graveyard",
}

local providers = {
	set = {
		{key = "mino", label = "Mino", url = "https://catboy.best"},
		{key = "akatsuki", label = "Akatsuki", url = "https://akatsuki.gg"},
	},
	pack = {{key = "etterna", label = "EtternaOnline", url = "https://etternaonline.com"}},
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
	self.mode_filter = "mania"
	self.search_generation = 0
	self.searching = false

	self.thumbnail_cache = ThumbnailCache(function(url)
		return ui.game.backgroundModel:loadImage(url, "http")
	end, 100)

	self.backdrop = self.root:add(View()):anchorFill(0, 0, 0, 0)
	self.backdrop:add(Panel({color = Colors.background})):anchorFill(0, 0, 0, 0)
	self.backdrop:add(Scrim()):anchorFill(0, 0, 0, 0)

	self.header = self.root:add(Panel({color = HEADER_COLOR, line_color = HEADER_LINE_COLOR, lines = {bottom = true}}))
	self.header:anchorFixed(0, 0, 1920, 106):fillWidth(0, 0)
	self.title = self.root:add(Label({font_name = "bold", font_size = 42, text = "Downloadable content"}))
	self.title:setPosition(40, 20)
	self.status = self.root:add(Label({font_name = "regular", font_size = 16, text = ""}))
	self.status:setPosition(40, 72)

	local popup = PopupContainer()
	self.popup = popup
	-- The controls sit directly on the backdrop, like the song select toolbar.
	self.toolbar = self.root:add(View())
	self.toolbar:fillWidth(EDGE, EDGE):setHeight(TOOLBAR_HEIGHT):addPosition(0, TOOLBAR_TOP)
	local controls = self.toolbar:add(TrackContainer({direction = "row", gap = 10}))
	controls:anchorFill(0, 0, 0, 0)

	local type_options = {}
	for i, item in ipairs(content_types) do
		type_options[i] = {label = item.label, value = item.key}
	end
	self.type_control = controls:add(Dropdown({
		label = "TYPE",
		options = type_options,
		value = self.content_type,
		popup_container = popup,
		on_change = function(value) self:setContentType(value) end,
	}), 240)

	self.search = controls:add(SearchField({
		placeholder = "Search downloadable content...",
		on_change = function(text)
			self.query = text
			self.page = 1
			self:setPageLabel(1)
			self:debounceSearch()
		end,
	}), "*")

	local status_options = {}
	for i, key in ipairs(osu_statuses) do
		status_options[i] = {label = osu_status_labels[key], value = key}
	end
	self.status_control = controls:add(Dropdown({
		label = "STATUS",
		options = status_options,
		value = self.status_filter,
		popup_container = popup,
		on_change = function(value) self:setStatusFilter(value) end,
	}), 190)

	local mode_options = {}
	for i, key in ipairs(osu_modes) do
		mode_options[i] = {label = osu_mode_labels[key], value = key}
	end
	self.mode_control = controls:add(Dropdown({
		label = "MODE",
		options = mode_options,
		value = self.mode_filter,
		popup_container = popup,
		on_change = function(value) self:setModeFilter(value) end,
	}), 190)

	self.sidebar = self.root:add(View())
	self.sidebar:setWidth(240):fillHeight(190, 82):addPosition(40, 0)
	self.list_host = self.root:add(View())
	self.list_host:anchorFill(318, 190, 390, 82)
	self.list_host:add(DlcPanel(PANEL_COLOR)):anchorFill(0, 0, 0, 0)
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
	self.queue_panel = self.root:add(DlcPanel(PANEL_COLOR))
	self.queue_panel:setWidth(310):fillHeight(230, 82):setAlignmentX(1):setOffset(-40, 0)
	self.queue = self.root:add(DlcQueue())
	self.queue:setWidth(310):fillHeight(230, 82):setAlignmentX(1):setOffset(-40, 0)

	self.back = self.root:add(IconTextButton({
		text = "Back",
		icon = Resources.sprites.icon_undo_2,
		variant = "danger",
		font_size = 18,
		padding_left = 24,
		padding_right = 30,
		on_click = function() ui:setScreen(ui.main_menu, true) end,
	}))
	self.back:setAlignment(0, 1):setOffset(EDGE, -FOOTER_BOTTOM)

	self.pagination = self.root:add(FlowContainer({direction = "row", gap = 12, align = 0.5}))
	self.previous = self.pagination:add(IconTextButton({
		text = "",
		icon = Resources.sprites.icon_chevron_left,
		gap = 0,
		padding_left = 16,
		padding_right = 16,
		on_click = function() self:setPage(self.page - 1) end,
	}))
	self.page_label = self.pagination:add(Label({font_name = "medium", font_size = 17, text = "Page 1", align = "center"}))
	self.page_label:setSize(PAGE_LABEL_WIDTH, 30)
	self.next = self.pagination:add(IconTextButton({
		text = "",
		icon = Resources.sprites.icon_chevron_right,
		icon_after = true,
		gap = 0,
		padding_left = 16,
		padding_right = 16,
		on_click = function() self:setPage(self.page + 1) end,
	}))
	self.pagination:fitContent():setAlignment(0.5, 1):setOffset(0, -FOOTER_BOTTOM)

	-- Added last so the dropdown lists are drawn above the rest of the screen.
	self.root:add(popup)
	self:rebuildSidebar()
	self:refreshQueue()
end

---Label:setText resizes the label to its text, which would shift the pagination row
---that was packed around a fixed-width label.
---@param page integer
function Dlc:setPageLabel(page)
	self.page_label:setText("Page " .. page)
	self.page_label:setSize(PAGE_LABEL_WIDTH, 30)
end

function Dlc:refreshQueue()
	local tasks = {}
	for _, task in pairs(self.ui.game.dlcManager.tasks) do tasks[#tasks + 1] = task end
	table.sort(tasks, function(a, b) return tostring(a.id) < tostring(b.id) end)
	self.queue:setTasks(tasks)
end

function Dlc:rebuildSidebar()
	self.status_control:setVisible(self.content_type == "set")
	self.mode_control:setVisible(self.content_type == "set")

	self.sidebar:clear()
	local provider_title = self.sidebar:add(Label({font_name = "bold", font_size = 16, text = "PROVIDER"}))
	provider_title:setPosition(12, 0)
	local choices = providers[self.content_type]
	if #choices > 0 then
		local provider_panel = self.sidebar:add(DlcPanel(PANEL_COLOR))
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

	local current
	for _, item in ipairs(choices) do
		if item.key == self.provider then current = item end
	end
	if current and current.url then
		local visit = self.sidebar:add(Button("Visit website", function()
			self.ui.modal_manager:attachExternalLink(current.label, current.url)
		end, {variant = "secondary", font_name = "medium", font_size = 16}))
		visit:setSize(240, 40):setPosition(0, 32 + #choices * 49 - 5 + 14)
	end
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
	self:setPageLabel(1)
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
	self:setPageLabel(1)
	self:rebuildSidebar()
	self:cancelPendingSearch()
	self:searchContent()
end

---@param status string
function Dlc:setStatusFilter(status)
	if self.status_filter == status then return end
	self.status_filter = status
	self.page = 1
	self:setPageLabel(1)
	self:cancelPendingSearch()
	self:searchContent()
end

---@param mode string
function Dlc:setModeFilter(mode)
	if self.mode_filter == mode then return end
	self.mode_filter = mode
	self.page = 1
	self:setPageLabel(1)
	self:cancelPendingSearch()
	self:searchContent()
end

---@param page integer
function Dlc:setPage(page)
	if page < 1 or page == self.page then return end
	self.page = page
	self:setPageLabel(page)
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
	local query, page, provider, mode = self.query, self.page, self.provider, self.mode_filter
	local status = self.status_filter
	if status == "any" and provider ~= "mino" then status = "all" end
	thread.coro(function()
		local results, err = self.ui.game.dlcManager:search(query, {page = page, status = status, mode = mode}, provider)
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
