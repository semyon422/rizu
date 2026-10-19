local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local ModalCloseButton = require("ui.views.ModalCloseButton")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local SettingsFilter = require("ui.modals.config.SettingsFilter")
local SectionItem = require("ui.modals.config.SectionItem")
local Textbox = require("ui.views.Textbox")
local UiActions = require("ui.UiActions")
local AudioSection = require("ui.modals.config.sections.Audio")
local BindingsSection = require("ui.modals.config.sections.Bindings")
local GameplaySection = require("ui.modals.config.sections.Gameplay")
local GameplayViewportSection = require("ui.modals.config.sections.GameplayViewport")
local LayoutSection = require("ui.modals.config.sections.Layout")
local OffsetSection = require("ui.modals.config.sections.Offset")
local OtherSection = require("ui.modals.config.sections.Other")
local RendererSection = require("ui.modals.config.sections.Renderer")
local UserInterfaceSection = require("ui.modals.config.sections.UserInterface")

---@class ui.modals.config.Config : ui.ModalView
---@operator call: ui.modals.config.Config
---@field ui_config ui.UiConfig
---@field settings rizu.config.Config
---@field app rizu.api.App
---@field popup_container ui.views.PopupContainer
---@field sections ui.modals.config.Section[]
---@field section_headers {[ui.modals.config.Section]: gui.View}
---@field section_items {[ui.modals.config.Section]: ui.modals.config.SectionItem}
---@field search ui.views.Textbox
---@field no_results gui.View
---@field query string
---@field private reset_scroll boolean
---@field section_list gui.layout.FlowContainer
---@field form ui.views.form.Form
---@field form_selection ui.views.form.FormSelection
---@field scroll_view gui.ScrollView
---@field background gui.NineSliceUsage
---@field list_background gui.NineSliceUsage
---@field private settings_invalidated boolean
---@field private on_language_change fun()
---@field private on_diff_column_change fun()
local Config = ModalView + {}

local MODAL_WIDTH = 1060
local MODAL_HEIGHT = 740
local LIST_PANEL_WIDTH = 740
local LIST_WIDTH = 635
local LIST_LEFT_WIDTH = MODAL_WIDTH - LIST_PANEL_WIDTH
local SEARCH_Y = 20
local SEARCH_HEIGHT = 40

---@param ui_config ui.UiConfig
---@param settings rizu.config.Config
---@param popup_container ui.views.PopupContainer
---@param on_close fun()
---@param localization ui.localization.Localization
---@param on_language_change fun()
---@param app rizu.api.App
---@param on_diff_column_change fun()
function Config:new(ui_config, settings, popup_container, on_close, localization, on_language_change, app, on_diff_column_change)
	ModalView.new(self)
	self.ui_config = ui_config
	self.settings = settings
	self.app = app
	self.popup_container = popup_container
	self.localization = localization
	self.on_language_change = on_language_change
	self.on_diff_column_change = on_diff_column_change
	self.form = Form({
		direction = "column",
		gap = 18,
		padding = {0, 16, 0, 16},
	})
	self.sections = self:createSections()
	self.section_headers = {}
	self.section_items = {}
	self.query = ""
	self.reset_scroll = false
	self.settings_invalidated = false

	self:setSize(MODAL_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setOpacity(0)
	self:setVisible(false)
	self:setClip(true)
	self.handles_mouse_input = true

	self.section_list = FlowContainer({direction = "column", gap = 4, padding = 20})
	for _, section in ipairs(self.sections) do
		self.section_items[section] = SectionItem(section, function(clicked)
			self:scrollToSection(clicked)
		end)
	end
	self:updateSectionList(self.sections)
	self.section_list:setOffset(0, SEARCH_Y + SEARCH_HEIGHT)

	self.search = Textbox({
		placeholder = localization:get("settings.search_placeholder"),
		icon = Resources.sprites.icon_search,
		blur_on_accept = true,
		blur_on_cancel = true,
		on_change = function(text)
			self:setQuery(text)
		end,
	})
	self.search:anchorFixed(20, SEARCH_Y, LIST_LEFT_WIDTH - 40, SEARCH_HEIGHT)

	self.no_results = Label({font_name = "medium", font_size = 16, text = localization:get("settings.no_results")})
	self.no_results:setOffset(LIST_LEFT_WIDTH + 36, 36)
	self.no_results:setVisible(false)

	self.scroll_view = ScrollView(self.form)
	self.scroll_view:anchorFixed(
		MODAL_WIDTH - LIST_PANEL_WIDTH + (LIST_PANEL_WIDTH - LIST_WIDTH) / 2,
		0,
		LIST_WIDTH + 2,
		MODAL_HEIGHT
	)

	local sprites = Resources.sprites
	local modal_sprites = {
		sprites.nineslice_modal_lt,
		sprites.nineslice_modal_t,
		sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l,
		sprites.nineslice_modal_c,
		sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb,
		sprites.nineslice_modal_b,
		sprites.nineslice_modal_rb,
	}
	self.background = NineSliceUsage(modal_sprites)
	self.list_background = NineSliceUsage(modal_sprites)

	self:add(self.section_list)
	self:add(self.search)
	self.close_button = self:add(ModalCloseButton(on_close, localization:get("settings.close")))
	self.close_button:anchorFixed(20, 0, 280, 48):setAlignmentY(1):addPosition(0, -20)
	self:add(self.scroll_view)
	self:add(self.no_results)
	self.form_selection = self:add(FormSelection(self.form))
	for _, section in ipairs(self.sections) do
		section:setInvalidator(function()
			self:invalidateSettings()
		end)
	end
	self:rebuildSettings()
end

---@return ui.modals.config.Section[] sections
function Config:createSections()
	return {
		AudioSection(self.settings, self.localization, self.app, self.form, self.popup_container),
		GameplaySection(self.settings, self.ui_config, self.localization, self.form, self.popup_container),
		OffsetSection(self.settings, self.localization),
		LayoutSection(self.settings, self.form, self.popup_container, self.localization),
		RendererSection(self.settings, self.ui_config, self.localization),
		GameplayViewportSection(self.ui_config, self.localization),
		UserInterfaceSection(
			self.settings,
			self.ui_config,
			self.localization,
			self.form,
			self.popup_container,
			self.on_language_change,
			self.app,
			self.on_diff_column_change
		),
		BindingsSection(self.ui_config, self.localization),
		OtherSection(self.settings, self.ui_config, self.localization),
	}
end

function Config:invalidateSettings()
	self.settings_invalidated = true
end

---@param section ui.modals.config.Section
---@return gui.layout.FlowContainer header
local function createSectionHeader(section)
	local header = FlowContainer({direction = "row", gap = 12, align = 0.5, padding = {0, 20, 0, 0}})
	header:add(Image(section.icon, nil, Colors.text))
	header:add(Label({font_name = "bold", font_size = 32, text = section.name}))
	header:fitContent()
	return header
end

---Scrolls the settings list so the section's header is at the top.
---@param section ui.modals.config.Section
function Config:scrollToSection(section)
	local header = self.section_headers[section]
	if not header then
		return
	end
	local x, y = header.world_transform:transformPoint(0, 0)
	local _, local_y = self.scroll_view.world_transform:inverseTransformPoint(x, y)
	self.scroll_view:scrollTo(self.scroll_view:getScrollPosition() + local_y)
end

---Shows only the given sections' buttons, in section order.
---@param visible ui.modals.config.Section[]
function Config:updateSectionList(visible)
	self.section_list:clear()
	for _, section in ipairs(visible) do
		self.section_list:add(self.section_items[section])
	end
	self.section_list:fitContent()
end

---@param query string
function Config:setQuery(query)
	if query == self.query then
		return
	end
	self.query = query
	self.reset_scroll = true
	self:invalidateSettings()
end

function Config:rebuildSettings()
	self.settings_invalidated = false
	local query_changed = self.reset_scroll
	self.reset_scroll = false
	local selected_index = self.form.selected_index
	self.form:closeActiveDropdown()
	self.form:clearSelection()
	self.form:clearRows()

	local terms = SettingsFilter.parse(self.query)
	self.section_headers = {}
	local visible = {}
	for _, section in ipairs(self.sections) do
		local controls = SettingsFilter.filterControls(terms, section.name, section:build())
		if #controls > 0 then
			visible[#visible + 1] = section
			local header = self.form:add(createSectionHeader(section))
			self.section_headers[section] = header
			for _, control in ipairs(controls) do
				self.form:add(control)
			end
		end
	end
	self:updateSectionList(visible)
	self.no_results:setVisible(#visible == 0)
	self.form:fitContent()
	if query_changed then
		self.scroll_view:scrollTo(0, true)
	elseif selected_index then
		self.form.selected_index = selected_index
		self.form:syncSelection()
	end
end

---@param dt number
function Config:update(dt)
	if self.settings_invalidated then
		self:rebuildSettings()
	end
end

---@param inputs gui.Inputs
function Config:onHandleInputs(inputs)
	-- Not while a textbox or a key binding capture has the keyboard.
	if not inputs.keyboard_focus and inputs:consumeActionJustPressed(UiActions.focus_search) then
		inputs:setKeyboardFocus(self.search, {control = false, shift = false, alt = false, super = false})
	end
end

function Config:show()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function Config:hide()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function Config:draw()
	Painter.setColorTable(Colors.surface)
	self.background:draw(self.width, self.height)

	Painter.setColorTable(Colors.panel)
	love.graphics.push()
	love.graphics.translate(MODAL_WIDTH - LIST_PANEL_WIDTH, 0)
	self.list_background:draw(LIST_PANEL_WIDTH, MODAL_HEIGHT)
	love.graphics.pop()
end

return Config
