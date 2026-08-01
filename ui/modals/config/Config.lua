local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local Form = require("ui.views.form.Form")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local InterfaceSection = require("ui.modals.config.sections.Interface")

---@class ui.modals.config.Config : ui.ModalView
---@operator call: ui.modals.config.Config
---@field ui_config ui.UiConfig
---@field sections ui.modals.config.Section[]
---@field form ui.views.form.Form
---@field scroll_view gui.ScrollView
---@field private settings_invalidated boolean
local Config = ModalView + {}

---@param ui_config ui.UiConfig
function Config:new(ui_config)
	ModalView.new(self)
	self.ui_config = ui_config
	self.sections = self:createSections()
	self.settings_invalidated = false

	self:setSize(890, 600)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
	self:setOpacity(0)
	self:setVisible(false)

	self.form = Form({direction = "column", gap = 18, padding = {20, 16, 20, 16}})
	self.scroll_view = ScrollView(self.form)
	self.scroll_view:anchorFixed(35, 40, 820, 520)

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt,
		sprites.nineslice_modal_t,
		sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l,
		sprites.nineslice_modal_c,
		sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb,
		sprites.nineslice_modal_b,
		sprites.nineslice_modal_rb,
	})

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
		InterfaceSection(self.ui_config),
	}
end

function Config:invalidateSettings()
	self.settings_invalidated = true
end

---@param section ui.modals.config.Section
---@return gui.layout.FlowContainer header
local function createSectionHeader(section)
	local header = FlowContainer({direction = "row", gap = 12, align = 0.5})
	header:add(Image(section.icon, "fit", Colors.text):setSize(28, 28))
	header:add(Label({font_name = "bold", font_size = 32, text = section.name}))
	header:fitContent()
	return header
end

function Config:rebuildSettings()
	self.settings_invalidated = false
	self.form:closeActiveDropdown()
	self.form:clearSelection()
	self.form.rows:clear()

	for _, section in ipairs(self.sections) do
		self.form:add(createSectionHeader(section))
		for _, control in ipairs(section:build()) do
			self.form:add(control)
		end
	end
	self.form:fitContent()
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
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return Config
