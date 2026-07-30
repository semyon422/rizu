local Checkbox = require("ui.views.form.Checkbox")
local Colors = require("ui.Colors")
local Dropdown = require("ui.views.form.Dropdown")
local Form = require("ui.views.form.Form")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local Slider = require("ui.views.form.Slider")
local Textbox = require("ui.views.form.Textbox")
local Label = require("ui.views.Label")

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

	local content = Form({direction = "column", gap = 18, padding = {20, 16, 20, 16}})
	content:add(Label({font_name = "bold", font_size = 32, text = "Form controls test"}))
	content:add(Checkbox({text = "Checkbox", checked = false}):setSize(780, 30))
	content:add(Slider({label = "Stepped slider", value = 5, min = 0, max = 10, step = 1, width = 780}))
	content:add(Slider({label = "Continuous slider", value = 0.5, min = 0, max = 1, width = 780}))
	content:add(Textbox({label = "Textbox", text = "Edit me", width = 780}))
	content:add(Textbox({label = "Empty textbox", placeholder = "Type something", width = 780}))

	---@type string[]
	local dropdown_options = {}
	for index = 1, 100 do
		dropdown_options[index] = ("Dropdown item %03d"):format(index)
	end
	content:add(Dropdown({
		label = "Dropdown with 100 items",
		options = dropdown_options,
		value = dropdown_options[50],
		width = 780,
	}))

	content:add(Checkbox({text = "Checkbox after dropdown", checked = true}):setSize(780, 30))
	content:add(Dropdown({
		label = "Second dropdown",
		options = {"Alpha", "Beta", "Gamma", "Delta"},
		value = "Beta",
		width = 780,
	}))
	content:add(Slider({label = "Slider after dropdown", value = 25, min = 0, max = 100, step = 5, width = 780}))
	content:add(Textbox({label = "Textbox after dropdown", text = "Last control", width = 780}))
	content:fitContent()

	self.scroll_view = ScrollView(content)
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
	self.background:draw(self.width, self.height)
end

return Config
