local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local Form = require("ui.views.form.Form")
local Image = require("ui.views.Image")
local InfoRow = require("ui.modals.config.rows.InfoRow")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NavItem = require("ui.modals.config.NavItem")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local SettingsFilter = require("ui.modals.config.SettingsFilter")
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

---@class ui.modals.config.ConfigV2 : ui.ModalView
---@operator call: ui.modals.config.ConfigV2
---@field ui_config ui.UiConfig
---@field settings rizu.config.Config
---@field app rizu.api.App
---@field popup_container ui.views.PopupContainer
---@field localization ui.localization.Localization
---@field sections ui.modals.config.Section[]
---@field section_headers {[ui.modals.config.Section]: gui.View}
---@field nav_items {[ui.modals.config.Section]: ui.modals.config.NavItem}
---@field visible_sections ui.modals.config.Section[]
---@field nav_list gui.layout.FlowContainer
---@field search ui.views.Textbox
---@field no_results gui.View
---@field query string
---@field form ui.views.form.Form
---@field scroll_view gui.ScrollView
---@field background gui.NineSliceUsage
---@field sidebar_background gui.NineSliceUsage
---@field private reset_scroll boolean
---@field private settings_invalidated boolean
---@field private on_language_change fun()
---@field private on_diff_column_change fun()
local ConfigV2 = ModalView + {}

local MODAL_WIDTH = 1060
local MODAL_HEIGHT = 740
local SIDEBAR_WIDTH = 260
local SIDEBAR_PADDING_X = 12
local SIDEBAR_PADDING_Y = 16
local SEARCH_HEIGHT = 40
local CONTENT_PADDING = {32, 8, 32, 32}
-- A section counts as in view once its header passes this line, as in the design's scroll spy.
local ACTIVE_SECTION_LINE = 40

---@param ui_config ui.UiConfig
---@param settings rizu.config.Config
---@param popup_container ui.views.PopupContainer
---@param on_close fun()
---@param localization ui.localization.Localization
---@param on_language_change fun()
---@param app rizu.api.App
---@param on_diff_column_change fun()
function ConfigV2:new(ui_config, settings, popup_container, on_close, localization, on_language_change, app, on_diff_column_change)
	ModalView.new(self)
	self.ui_config = ui_config
	self.settings = settings
	self.app = app
	self.popup_container = popup_container
	self.localization = localization
	self.on_language_change = on_language_change
	self.on_diff_column_change = on_diff_column_change
	self.form = Form({direction = "column", padding = CONTENT_PADDING})
	self.sections = self:createSections()
	self.section_headers = {}
	self.nav_items = {}
	self.visible_sections = {}
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

	self.background = NineSliceUsage(Resources.nine_slices.config_v2_modal)
	self.sidebar_background = NineSliceUsage(Resources.nine_slices.config_v2_sidebar)

	local sidebar_inner_width = SIDEBAR_WIDTH - SIDEBAR_PADDING_X * 2
	self.search = self:add(Textbox({
		placeholder = localization:get("settings.search_placeholder"),
		icon = Resources.sprites.icon_search,
		background = true,
		blur_on_accept = true,
		blur_on_cancel = true,
		on_change = function(text)
			self:setQuery(text)
		end,
	}))
	self.search:anchorFixed(SIDEBAR_PADDING_X, SIDEBAR_PADDING_Y, sidebar_inner_width, SEARCH_HEIGHT)

	local nav_y = SIDEBAR_PADDING_Y + SEARCH_HEIGHT + 12
	self.nav_list = self:add(FlowContainer({direction = "column", gap = 2}))
	self.nav_list:setPosition(SIDEBAR_PADDING_X, nav_y)
	for _, section in ipairs(self.sections) do
		local item = NavItem(section.icon, section.name, function()
			self:scrollToSection(section)
		end)
		item:setWidth(sidebar_inner_width)
		self.nav_items[section] = item
	end

	local close = self:add(NavItem(Resources.sprites.icon_x, localization:get("settings.close"), on_close))
	close:anchorFixed(
		SIDEBAR_PADDING_X,
		MODAL_HEIGHT - SIDEBAR_PADDING_Y - NavItem.HEIGHT,
		sidebar_inner_width,
		NavItem.HEIGHT
	)

	self.scroll_view = self:add(ScrollView(self.form))
	self.scroll_view:anchorFixed(SIDEBAR_WIDTH, 1, MODAL_WIDTH - SIDEBAR_WIDTH - 1, MODAL_HEIGHT - 2)

	self.no_results = self:add(Label({font_name = "medium", font_size = 16, text = localization:get("settings.no_results")}))
	self.no_results:setOffset(SIDEBAR_WIDTH + CONTENT_PADDING[1], 32)
	self.no_results:setVisible(false)

	for _, section in ipairs(self.sections) do
		section:setInvalidator(function()
			self:invalidateSettings()
		end)
	end
	self:rebuildSettings()
end

---@return ui.modals.config.Section[] sections
function ConfigV2:createSections()
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

function ConfigV2:invalidateSettings()
	self.settings_invalidated = true
end

---@param section ui.modals.config.Section
---@return gui.layout.FlowContainer header
local function createSectionHeader(section)
	local header = FlowContainer({direction = "row", gap = 10, align = 0.5, padding = {0, 24, 0, 12}})
	header:add(Image(section.icon, "fit", Colors.accent)):setSize(20, 20)
	header:add(Label({font_name = "bold", font_size = 22, text = section.name}))
	header:fitContent()
	return header
end

---@param view gui.View
---@return number y The view's top in the scroll view's space.
function ConfigV2:getScrollLocalY(view)
	local x, y = view.world_transform:transformPoint(0, 0)
	local _, local_y = self.scroll_view.world_transform:inverseTransformPoint(x, y)
	return local_y
end

---Scrolls the settings list so the section's header is at the top.
---@param section ui.modals.config.Section
function ConfigV2:scrollToSection(section)
	local header = self.section_headers[section]
	if not header then
		return
	end
	local position = self.scroll_view:getScrollPosition() + self:getScrollLocalY(header) - CONTENT_PADDING[2]
	self.scroll_view:scrollTo(position)
end

---@param query string
function ConfigV2:setQuery(query)
	if query == self.query then
		return
	end
	self.query = query
	self.reset_scroll = true
	self:invalidateSettings()
end

---Wraps views without a row look, merging neighbors into one row, and places every row in its group.
---@param controls gui.View[]
---@return gui.View[] rows
function ConfigV2:createGroup(controls)
	local rows = {} ---@type gui.View[]
	for _, control in ipairs(controls) do
		---@cast control gui.View|{setting_row: ui.modals.config.rows.SettingRow?}
		if control.setting_row then
			rows[#rows + 1] = control
		else
			local info = rows[#rows]
			if not (InfoRow * info) then
				info = InfoRow()
				rows[#rows + 1] = info
			end
			---@cast info ui.modals.config.rows.InfoRow
			info:addContent(control)
		end
	end
	for index, row in ipairs(rows) do
		---@cast row ui.modals.config.rows.InfoRow
		row.setting_row:place(self.form, index == 1, index == #rows)
	end
	return rows
end

function ConfigV2:rebuildSettings()
	self.settings_invalidated = false
	local query_changed = self.reset_scroll
	self.reset_scroll = false
	local selected_index = self.form.selected_index
	self.form:closeActiveDropdown()
	self.form:clearSelection()
	self.form:clearRows()

	local terms = SettingsFilter.parse(self.query)
	self.section_headers = {}
	self.visible_sections = {}
	self.nav_list:clear()
	for _, section in ipairs(self.sections) do
		local controls = SettingsFilter.filterControls(terms, section.name, section:build())
		if #controls > 0 then
			self.visible_sections[#self.visible_sections + 1] = section
			self.section_headers[section] = self.form:add(createSectionHeader(section))
			for _, row in ipairs(self:createGroup(controls)) do
				self.form:add(row)
			end
			self.nav_list:add(self.nav_items[section])
		end
	end
	self.nav_list:fitContent()
	self.no_results:setVisible(#self.visible_sections == 0)
	self.form:fitContent()
	if query_changed then
		self.scroll_view:scrollTo(0, true)
	elseif selected_index then
		self.form.selected_index = selected_index
		self.form:syncSelection()
	end
end

---The last section whose header has scrolled past the top of the list.
function ConfigV2:updateActiveSection()
	local sections = self.visible_sections
	local active = sections[1]
	for _, section in ipairs(sections) do
		if self:getScrollLocalY(self.section_headers[section]) <= ACTIVE_SECTION_LINE then
			active = section
		end
	end
	-- Short last sections never reach the top.
	local scroll_view = self.scroll_view
	if scroll_view:getMaxScroll() > 0 and scroll_view:getScrollPosition() >= scroll_view:getMaxScroll() - 1 then
		active = sections[#sections]
	end
	for section, item in pairs(self.nav_items) do
		item.active = section == active
	end
end

---@param dt number
function ConfigV2:update(dt)
	if self.settings_invalidated then
		self:rebuildSettings()
	end
	self:updateActiveSection()
end

---@param inputs gui.Inputs
function ConfigV2:onHandleInputs(inputs)
	-- Not while a textbox or a key binding capture has the keyboard.
	if not inputs.keyboard_focus and inputs:consumeActionJustPressed(UiActions.focus_search) then
		inputs:setKeyboardFocus(self.search, {control = false, shift = false, alt = false, super = false})
	end
end

function ConfigV2:show()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function ConfigV2:hide()
	self.settings:save()
	self.ui_config:save()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function ConfigV2:draw()
	Painter.setColorRgb(1, 1, 1, 1)
	self.background:draw(self.width, self.height)

	love.graphics.push()
	love.graphics.translate(1, 1)
	self.sidebar_background:draw(SIDEBAR_WIDTH - 1, self.height - 2)
	love.graphics.pop()
end

return ConfigV2
