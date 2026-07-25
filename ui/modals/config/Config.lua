local ModalView = require("ui.ModalView")
local Resources = require("ui.Resources")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Checkbox = require("ui.views.Checkbox")
local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local ScrollView = require("gui.ScrollView")
local Textbox = require("ui.views.Textbox")

---@class ui.modals.config.Config : ui.ModalView
---@operator call: ui.modals.config.Config
---@field scroll_view gui.ScrollView
local Config = ModalView + {}

function Config:new()
	ModalView.new(self)
	self:setSize(890, 600)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
	self:setOpacity(0)
	self:setVisible(false)

	local content = FlowContainer({direction = "column", gap = 18, padding = {20, 16, 20, 16}})
	content:add(Label({font_name = "bold", font_size = 32, text = "Settings"}))
	content:add(Checkbox({text = "Enable background animations", checked = true}))
	content:add(Checkbox({text = "Show gameplay notifications", checked = true}))
	content:add(Checkbox({text = "Use compact song list"}))
	content:add(Textbox({text = "Player name", width = 780}))
	content:add(Textbox({text = "Audio device", width = 780}))
	content:add(Checkbox({text = "Enable hitsounds", checked = true}))
	content:add(Checkbox({text = "Dim background during gameplay", checked = true}))
	content:add(Textbox({text = "Screenshot directory", width = 780}))
	content:add(Checkbox({text = "Check for updates on startup", checked = true}))
	content:add(Checkbox({text = "Enable Discord presence", checked = true}))
	content:add(Textbox({text = "Online server address", width = 780}))
	content:add(Checkbox({text = "Send anonymous diagnostics"}))
	content:add(Checkbox({text = "Confirm before quitting", checked = true}))
	content:fitContent()

	self.scroll_view = ScrollView(content)
	self.scroll_view:anchorFixed(35, 40, 820, 520)
	self:add(self.scroll_view)
end

function Config:show()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
	self:scaleTo(1, 1, 0.4, "OutQuart")
end

function Config:hide()
	self:scaleTo(0.9, 0.9, 0.24, "InQuart")
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function Config:draw()
	Painter.setColorTable(Colors.panel)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, 0, 0, 0, self.width, self.height)
end

return Config
