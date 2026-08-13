local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local Section = require("ui.modals.config.Section")
local SectionItem = require("ui.modals.config.SectionItem")
local AudioSection = require("ui.modals.config.sections.Audio")
local GameplaySection = require("ui.modals.config.sections.Gameplay")
local GameplayViewportSection = require("ui.modals.config.sections.GameplayViewport")
local LayoutSection = require("ui.modals.config.sections.Layout")
local OffsetSection = require("ui.modals.config.sections.Offset")
local RendererSection = require("ui.modals.config.sections.Renderer")
local UserInterfaceSection = require("ui.modals.config.sections.UserInterface")

---@class ui.modals.config.Config : ui.ModalView
---@operator call: ui.modals.config.Config
---@field ui_config ui.UiConfig
---@field legacy_settings sphere.SettingsConfig
---@field speed_model sphere.SpeedModel
---@field sections ui.modals.config.Section[]
---@field all_section ui.modals.config.Section
---@field selected_section ui.modals.config.Section
---@field section_list gui.layout.FlowContainer
---@field form ui.views.form.Form
---@field form_selection ui.views.form.FormSelection
---@field scroll_view gui.ScrollView
---@field background gui.NineSliceUsage
---@field list_background gui.NineSliceUsage
---@field private settings_invalidated boolean
local Config = ModalView + {}

local MODAL_WIDTH = 1060
local MODAL_HEIGHT = 740
local LIST_PANEL_WIDTH = 740
local LIST_WIDTH = 635

---@param ui_config ui.UiConfig
---@param legacy_settings sphere.SettingsConfig
---@param speed_model sphere.SpeedModel
function Config:new(ui_config, legacy_settings, speed_model)
	ModalView.new(self)
	self.ui_config = ui_config
	self.legacy_settings = legacy_settings
	self.speed_model = speed_model
	self.sections = self:createSections()
	self.all_section = Section({
		name = "All",
		icon = Resources.sprites.icon_gear,
		build = function() return {} end,
	})
	self.selected_section = self.all_section
	self.settings_invalidated = false

	self:setSize(MODAL_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
	self:setOpacity(0)
	self:setVisible(false)
	self:setClip(true)
	self.handles_mouse_input = true

	self.section_list = FlowContainer({direction = "column", gap = 4, padding = 20})
	self.section_list:add(SectionItem(self.all_section, function(selected_section)
		self.selected_section = selected_section
		self:invalidateSettings()
	end))
	for _, section in ipairs(self.sections) do
		self.section_list:add(SectionItem(section, function(selected_section)
			self.selected_section = selected_section
			self:invalidateSettings()
		end))
	end
	self.section_list:fitContent()
	self.section_list:setOffset(0, 20)

	self.form = Form({direction = "column", gap = 18, padding = {0, 16, 0, 16}})
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
	self:add(self.scroll_view)
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
		AudioSection(self.legacy_settings),
		GameplaySection(self.legacy_settings, self.speed_model),
		OffsetSection(self.legacy_settings),
		LayoutSection(self.legacy_settings),
		RendererSection(self.legacy_settings, self.ui_config),
		GameplayViewportSection(self.ui_config),
		UserInterfaceSection(self.legacy_settings),
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

function Config:rebuildSettings()
	self.settings_invalidated = false
	local selected_index = self.form.selected_index
	self.form:closeActiveDropdown()
	self.form:clearSelection()
	self.form:clearRows()

	if self.selected_section == self.all_section then
		for _, section in ipairs(self.sections) do
			self.form:add(createSectionHeader(section))
			for _, control in ipairs(section:build()) do
				self.form:add(control)
			end
		end
	else
		local section = self.selected_section
		self.form:add(createSectionHeader(section))
		for _, control in ipairs(section:build()) do
			self.form:add(control)
		end
	end
	self.form:fitContent()
	if selected_index then
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
	Painter.setColorTable(Colors.panel_alt)
	self.background:draw(self.width, self.height)

	Painter.setColorTable(Colors.panel)
	love.graphics.push()
	love.graphics.translate(MODAL_WIDTH - LIST_PANEL_WIDTH, 0)
	self.list_background:draw(LIST_PANEL_WIDTH, MODAL_HEIGHT)
	love.graphics.pop()
end

return Config
