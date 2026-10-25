local View = require("gui.View")
local PaletteState = require("rizu.command.PaletteState")
local AiChat = require("ui.modals.ai_chat.AiChat")
local CommandPalette = require("ui.modals.command_palette.CommandPalette")
local ExternalLink = require("ui.modals.ExternalLink")
local ChartMutators = require("ui.modals.chart_mutators.ChartMutators")
local CollectionSelector = require("ui.modals.collections.CollectionSelector")
local NeedleToolRegistry = require("rizu.ai.NeedleToolRegistry")
local OverlayBackground = require("ui.views.OverlayBackground")
local Config = require("ui.modals.config.Config")
local Mapperatorinator = require("ui.modals.mapperatorinator.Mapperatorinator")
local Input = require("ui.modals.input.Input")
local Modifiers = require("ui.modals.modifiers.Modifiers")
local ColumnOrder = require("ui.modals.column_order.ColumnOrder")
local NoteSkins = require("ui.modals.note_skins.NoteSkins")
local HudElementPicker = require("ui.modals.hud_element_picker.HudElementPicker")
local TexturePicker = require("ui.modals.texture_picker.TexturePicker")
local Rescore = require("ui.modals.rescore.Rescore")
local Filters = require("ui.modals.filters.Filters")
local ScoreFilters = require("ui.modals.score_filters.ScoreFilters")
local ScoreSystems = require("ui.modals.score_systems.ScoreSystems")
local LocationEditor = require("ui.modals.locations.LocationEditor")
local CreateRoom = require("ui.modals.lobby.CreateRoom")
local Login = require("ui.modals.login.Login")
local VideoExport = require("ui.modals.video_export.VideoExport")
local UiActions = require("ui.UiActions")

---@class ui.ModalManager : gui.View
---@operator call: ui.ModalManager
---@field ui ui.UserInterface
---@field palette ui.modals.command_palette.CommandPalette
---@field ai_chat ui.modals.ai_chat.AiChat?
---@field config ui.modals.config.Config
---@field external_link ui.modals.ExternalLink
---@field mapperatorinator ui.modals.mapperatorinator.Mapperatorinator
---@field input ui.modals.input.Input
---@field modifiers ui.modals.modifiers.Modifiers
---@field column_order ui.modals.column_order.ColumnOrder
---@field note_skins ui.modals.note_skins.NoteSkins
---@field hud_element_picker ui.modals.hud_element_picker.HudElementPicker
---@field texture_picker ui.modals.texture_picker.TexturePicker
---@field rescore ui.modals.rescore.Rescore
---@field chart_mutators ui.modals.chart_mutators.ChartMutators
---@field collection_selector ui.modals.collections.CollectionSelector
---@field filters ui.modals.filters.Filters
---@field score_filters ui.modals.score_filters.ScoreFilters
---@field score_systems ui.modals.score_systems.ScoreSystems
---@field location_editor ui.modals.locations.LocationEditor
---@field create_room ui.modals.lobby.CreateRoom
---@field login ui.modals.login.Login
---@field video_export ui.modals.video_export.VideoExport
---@field active_view ui.ModalView?
---@field popup_container ui.views.PopupContainer
local ModalManager = View + {}

---@param ui ui.UserInterface
---@param popup_container ui.views.PopupContainer
function ModalManager:new(ui, popup_container)
	View.new(self)
	self:anchorFill(0, 0, 0, 0)
	self.handles_keyboard_input = true
	self.keyboard_input_fallback = true
	self.ui = ui
	self.popup_container = popup_container

	self.active_view = nil
	local localization = ui.localization
	-- shortcut: the command palette, AI, multiplayer and mapperatorinator modals still need the game, so
	-- they are not built without it (not covered by ui.api yet). Attaching a missing modal does nothing.
	local game = not ui.api.fake and ui.game

	if game then
		local needle_tools = NeedleToolRegistry(ui.command_registry)
		self.palette = CommandPalette(PaletteState(ui.command_registry), function()
			self:modalClosed(self.palette)
		end, game.needleModel, needle_tools)
	end

	self.bg = self:add(OverlayBackground(function()
		self:hideModal()
	end))
	self.config = self:addModal(Config(ui.config, ui.api.settings, popup_container,
		function() self:hideModal(self.config) end,
		localization,
		function()
			ui.config:save()
			ui.api.app:requestReload()
		end,
		ui.api.app,
		function()
			ui.api.charts:refresh()
		end))
	self.external_link = self:addModal(ExternalLink(localization, function()
		self:hideModal(self.external_link)
	end))
	local function modifiers_changed()
		-- TODO: This callback chain stinks. The game core should emit modifier-change events.
		ui.song_select:updateModifiers()
	end
	if game then
		self.mapperatorinator = self:addModal(Mapperatorinator(
			ui.mapperatorinator_workflow,
			ui.mapperatorinator_config,
			function() self:detachMapperatorinator() end,
			popup_container
		))
	end
	self.input = self:addModal(Input(ui.api.input, function() self:hideModal(self.input) end, localization))
	ui.api.charts:on("selection_changed", function() self.input:receive() end)
	self.modifiers = self:addModal(Modifiers(ui.api.play,
		function() self:hideModal(self.modifiers) end, localization,
		function() self:showModal(self.column_order) end,
		function() self:showModal(self.score_systems) end))
	self.score_systems = self:addModal(ScoreSystems(ui.api.scores, ui.api.library,
		function() self:showModal(self.modifiers) end, localization))
	self.column_order = self:addModal(ColumnOrder(ui.api.play,
		function() self:showModal(self.modifiers) end, localization))
	self.rescore = self:addModal(Rescore(ui.api.result,
		function() ui.result:updateInfo() end,
		function() self:hideModal(self.rescore) end, localization))
	self.note_skins = self:addModal(NoteSkins(ui.api.skins,
		function() self:hideModal(self.note_skins) end, localization, function()
			self:hideModal(self.note_skins)
			ui:loadSelectedChart(true, true, true)
		end))
	self.hud_element_picker = self:addModal(HudElementPicker(ui.api.gameplay,
		function() self:hideModal(self.hud_element_picker) end, localization))
	self.texture_picker = self:addModal(TexturePicker(function() self:hideModal(self.texture_picker) end,
		localization))
	self.chart_mutators = self:addModal(ChartMutators(ui.api.play, modifiers_changed, localization))
	self.collection_selector = self:addModal(CollectionSelector(function()
		self:hideModal(self.collection_selector)
	end, localization))
	self.filters = self:addModal(Filters(ui.api.charts, popup_container, localization))
	self.score_filters = self:addModal(ScoreFilters(ui.api.library, ui.api.scores, popup_container, function()
		self:hideModal(self.score_filters)
	end, localization))
	self.location_editor = self:addModal(LocationEditor(ui, function()
		if ui.locations then ui.locations:refresh() end
	end))
	self.login = self:addModal(Login(ui, function() self:hideModal(self.login) end))
	self.video_export = self:addModal(VideoExport(ui.api, function() self:hideModal(self.video_export) end))
	if game then
		self.create_room = self:addModal(CreateRoom(ui))
		if game.aiChatModel then
			self.ai_chat = self:addModal(AiChat(game.aiChatModel, function()
				self:hideModal(self.ai_chat)
			end))
		end
		self:addModal(self.palette)
	end
end

---@generic T: ui.ModalView
---@param view T
---@return T
function ModalManager:addModal(view)
	return self:add(view)
end

---@param view ui.ModalView? nil for a modal that is not built without the game
---@return boolean shown
function ModalManager:showModal(view)
	if not view or self.active_view == view then
		return false
	end
	if self.active_view and self.active_view.locked then
		return false
	end
	if self.active_view then
		self:hideModal(self.active_view)
	end

	self.active_view = view
	view:show()
	self.bg:show()
	local inputs = self.screen and self.screen.inputs
	if inputs then
		inputs:pushFocusScope(view)
		if view.handles_keyboard_input then
			inputs:setKeyboardFocus(view, {control = false, shift = false, alt = false, super = false})
		end
	end
	return true
end

---@param view ui.ModalView?
---@return boolean hidden
function ModalManager:hideModal(view)
	view = view or self.active_view
	if not view or self.active_view ~= view then
		return false
	end
	-- A locked modal is busy and closes itself when it is done.
	if view.locked then
		return false
	end
	if view == self.palette and self.palette.needle_model then
		self.palette.needle_model:cancel()
	end
	view:hide()
	self:modalClosed(view)
	return true
end

---@private
---@param view ui.ModalView
function ModalManager:modalClosed(view)
	if self.active_view ~= view then
		return
	end
	self.active_view = nil
	-- A popup opened from the modal may hold a focus scope above the modal's one.
	local popup_owner = self.popup_container.owner
	if popup_owner then
		popup_owner:close()
	end
	local inputs = self.screen and self.screen.inputs
	if inputs then
		-- The focused modal may have closed itself while raw key events were
		-- dispatched. Consume cancel here so the later action phase cannot also
		-- close the navigation screen.
		inputs:consumeActionJustPressed(UiActions.cancel)
		inputs:setKeyboardFocus(nil, {control = false, shift = false, alt = false, super = false})
		inputs:popFocusScope(view)
	end
	self.bg:hide()
end

---@param inputs gui.Inputs
function ModalManager:onHandleInputs(inputs)
	if self.active_view and inputs:consumeActionJustPressed(UiActions.cancel) then
		self:hideModal()
	end
end

---@param on_added fun(id: string) Gets the skin editor section id of the new element.
---@return boolean attached
function ModalManager:attachHudElementPicker(on_added)
	self.hud_element_picker:open(on_added)
	return self:showModal(self.hud_element_picker)
end

---@param property rizu.api.Gameplay.SkinProperty A skin editor "texture" property.
---@param on_picked fun(value: any)
---@return boolean attached
function ModalManager:attachTexturePicker(property, on_picked)
	self.texture_picker:open(property, on_picked)
	return self:showModal(self.texture_picker)
end

---@return boolean attached
function ModalManager:attachVideoExport()
	self.video_export:open()
	return self:showModal(self.video_export)
end

---@return boolean attached
function ModalManager:attachPalette()
	if not self.palette or self.active_view == self.palette then
		return false
	end
	self.palette:reset()
	return self:showModal(self.palette)
end

---@return boolean detached
function ModalManager:detachPalette()
	return self:hideModal(self.palette)
end

---@return boolean attached
function ModalManager:attachChat()
	return self.ai_chat ~= nil and self:showModal(self.ai_chat)
end

---@return boolean detached
function ModalManager:detachChat()
	return self.ai_chat ~= nil and self:hideModal(self.ai_chat)
end

---@return boolean attached
function ModalManager:attachConfig()
	return self:showModal(self.config)
end

---@return boolean detached
function ModalManager:detachConfig()
	return self:hideModal(self.config)
end

---@param title string
---@param url string
---@return boolean attached
function ModalManager:attachExternalLink(title, url)
	self.external_link:open(title, url)
	return self:showModal(self.external_link)
end

---@return boolean detached
function ModalManager:detachExternalLink()
	return self:hideModal(self.external_link)
end

---@return boolean attached
function ModalManager:attachCreateRoom()
	return self:showModal(self.create_room)
end

---@return boolean detached
function ModalManager:detachCreateRoom()
	return self:hideModal(self.create_room)
end

---@return boolean attached
function ModalManager:attachLogin()
	return self:showModal(self.login)
end

---@return boolean detached
function ModalManager:detachLogin()
	return self:hideModal(self.login)
end

---@return boolean attached
function ModalManager:attachMapperatorinator()
	return self:showModal(self.mapperatorinator)
end

---@return boolean detached
function ModalManager:detachMapperatorinator()
	return self:hideModal(self.mapperatorinator)
end

---@return boolean attached
function ModalManager:attachInput()
	return self:showModal(self.input)
end

---@return boolean detached
function ModalManager:detachInput()
	return self:hideModal(self.input)
end

---@return boolean attached
function ModalManager:attachModifiers()
	return self:showModal(self.modifiers)
end

---@return boolean detached
function ModalManager:detachModifiers()
	return self:hideModal(self.modifiers)
end

---@return boolean attached
function ModalManager:attachRescore()
	return self:showModal(self.rescore)
end

---@return boolean detached
function ModalManager:detachRescore()
	return self:hideModal(self.rescore)
end

---@return boolean attached
function ModalManager:attachNoteSkins()
	return self:showModal(self.note_skins)
end

---@return boolean detached
function ModalManager:detachNoteSkins()
	return self:hideModal(self.note_skins)
end

---@return boolean attached
function ModalManager:attachChartMutators()
	return self:showModal(self.chart_mutators)
end

---@return boolean detached
function ModalManager:detachChartMutators()
	return self:hideModal(self.chart_mutators)
end

---@param options ui.screens.song_select_v2.DropdownOption[]
---@param value any
---@param on_change fun(value: any)
---@return boolean attached
function ModalManager:attachCollectionSelector(options, value, on_change)
	if self.active_view == self.collection_selector then return false end
	self.collection_selector:open(options, value, on_change)
	return self:showModal(self.collection_selector)
end

---@return boolean attached
function ModalManager:attachFilters()
	return self:showModal(self.filters)
end

---@param location rizu.api.Location?
---@return boolean attached
function ModalManager:attachLocationEditor(location)
	if self.active_view == self.location_editor then
		return false
	end
	self.location_editor:open(location)
	return true
end

---@return boolean detached
function ModalManager:detachFilters()
	return self:hideModal(self.filters)
end

---@return boolean attached
function ModalManager:attachScoreFilters()
	return self:showModal(self.score_filters)
end

return ModalManager
