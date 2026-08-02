local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local SpringValue = require("gui.anim.SpringValue")
local Form = require("ui.views.form.Form")
local FormNavigation = require("ui.views.form.FormNavigation")
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
local LayoutSection = require("ui.modals.config.sections.Layout")
local OffsetSection = require("ui.modals.config.sections.Offset")
local RendererSection = require("ui.modals.config.sections.Renderer")
local UserInterfaceSection = require("ui.modals.config.sections.UserInterface")

---@class ui.modals.config.Config : ui.ModalView
---@operator call: ui.modals.config.Config
---@field ui_config ui.UiConfig
---@field legacy_settings sphere.SettingsConfig
---@field sections ui.modals.config.Section[]
---@field all_section ui.modals.config.Section
---@field selected_section ui.modals.config.Section
---@field section_list gui.layout.FlowContainer
---@field form ui.views.form.Form
---@field scroll_view gui.ScrollView
---@field background gui.NineSliceUsage
---@field list_background gui.NineSliceUsage
---@field selection_x number
---@field selection_y gui.anim.SpringValue
---@field selection_width number
---@field selection_height gui.anim.SpringValue
---@field private selection_visible boolean
---@field private settings_invalidated boolean
local Config = ModalView + {}

local MODAL_WIDTH = 1060
local MODAL_HEIGHT = 740
local LIST_PANEL_WIDTH = 740
local LIST_WIDTH = 635
local SELECTION_WIDTH = 4
local SELECTION_GAP = 10

---@param ui_config ui.UiConfig
---@param legacy_settings sphere.SettingsConfig
function Config:new(ui_config, legacy_settings)
	ModalView.new(self)
	self.ui_config = ui_config
	self.legacy_settings = legacy_settings
	self.sections = self:createSections()
	self.all_section = Section({
		name = "All",
		icon = Resources.sprites.icon_gear,
		build = function() return {} end,
	})
	self.selected_section = self.all_section
	self.settings_invalidated = false
	self.selection_visible = false
	self.selection_x = 0
	self.selection_y = SpringValue({stiffness = 360, damping = 34})
	self.selection_width = 0
	self.selection_height = SpringValue()

	self:setSize(MODAL_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
	self:setOpacity(0)
	self:setVisible(false)
	self:setClip(true)

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
		OffsetSection(self.legacy_settings),
		LayoutSection(self.legacy_settings),
		RendererSection(self.legacy_settings, self.ui_config),
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
	self.form.rows:clear()

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

function Config:updateSelection()
	local form = self.form
	form:updateSelection()
	if not form.selection_visible then
		self.selection_visible = false
		return
	end

	local target_x = assert(form.selection_target_x)
	local target_y = assert(form.selection_target_y)
	local target_width = assert(form.selection_target_width)
	local target_height = assert(form.selection_target_height)

	-- Animate in form-local space. The form's world transform contains the
	-- current scroll offset, which is applied later without spring lag.
	self.selection_x = target_x
	self.selection_width = target_width
	if self.selection_visible then
		self.selection_y:set(target_y)
		self.selection_height:set(target_height)
	else
		self.selection_y:snap(target_y)
		self.selection_height:snap(target_height)
		self.selection_visible = true
	end
end

---@param dt number
function Config:update(dt)
	local rebuilt = self.settings_invalidated
	if rebuilt then
		self:rebuildSettings()
	else
		self:updateSelection()
	end
	self.selection_y:update(dt)
	self.selection_height:update(dt)
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

	if self.selection_visible then
		local form = self.form
		local selection_x = self.selection_x
		local selection_y = self.selection_y:get()
		local selection_width = self.selection_width
		local selection_height = self.selection_height:get()
		local min_x, min_y = math.huge, math.huge
		local max_y = -math.huge
		local corners = {
			{selection_x, selection_y},
			{selection_x + selection_width, selection_y},
			{selection_x, selection_y + selection_height},
			{selection_x + selection_width, selection_y + selection_height},
		}
		for _, corner in ipairs(corners) do
			local world_x, world_y = form.world_transform:transformPoint(corner[1], corner[2])
			local x, y = self.world_transform:inverseTransformPoint(world_x, world_y)
			min_x, min_y = math.min(min_x, x), math.min(min_y, y)
			max_y = math.max(max_y, y)
		end

		Painter.setColorTable(Colors.text_muted)
		Painter.setOpacity(form.navigation == FormNavigation.Keyboard and 1 or 0.5)
		love.graphics.rectangle(
			"fill",
			min_x - SELECTION_GAP - SELECTION_WIDTH,
			min_y,
			SELECTION_WIDTH,
			max_y - min_y
		)
	end
end

return Config
