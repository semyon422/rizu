local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.modals.ExternalLink : ui.ModalView
---@operator call: ui.modals.ExternalLink
---@field url string
---@field title ui.views.Label
---@field message ui.views.Label
---@field url_label ui.views.Label
---@field actions gui.layout.FlowContainer
---@field on_close fun()
local ExternalLink = ModalView + {}

local MIN_WIDTH = 560
local PADDING_X = 42
local PADDING_TOP = 34
local PADDING_BOTTOM = 34
local GAP = 20

---@param localization ui.localization.Localization
---@param on_close fun()
function ExternalLink:new(localization, on_close)
	ModalView.new(self)
	self.localization = localization
	self.on_close = on_close
	self.url = ""
	self:setSize(MIN_WIDTH, 1):setAlignment(0.5, 0.5):setPivot(0.5, 0.5)
	self:setOpacity(0):setVisible(false):setClip(true)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt, sprites.nineslice_modal_t, sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l, sprites.nineslice_modal_c, sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb, sprites.nineslice_modal_b, sprites.nineslice_modal_rb,
	})

	self.title = self:add(Label({font_name = "bold", font_size = 36}))
	self.title:setPosition(PADDING_X, PADDING_TOP)
	self.message = self:add(Label({
		font_name = "regular",
		font_size = 18,
		color = Colors.muted,
		text = localization:get("external_link.message"),
	}))
	self.url_label = self:add(Label({font_name = "medium", font_size = 18, color = Colors.accent}))

	self.actions = self:add(FlowContainer({direction = "row", gap = 14, align = 0.5}))
	local ok = self.actions:add(Button(localization:get("external_link.ok"), function()
		love.system.openURL(self.url)
		self.on_close()
	end, {variant = "primary", shape = "capsule", font_size = 18}))
	ok:setSize(150, 48)
	local no = self.actions:add(Button(localization:get("external_link.no"), self.on_close, {
		variant = "secondary", shape = "capsule", font_size = 18,
	}))
	no:setSize(150, 48)
	self.actions:fitContent()
end

---@param title string
---@param url string
function ExternalLink:open(title, url)
	assert(url ~= "", "browser link URL must not be empty")
	self.url = url
	self.title:setText(title)
	self.url_label:setText(url)

	local title_bottom = PADDING_TOP + self.title.offset_max[2] - self.title.offset_min[2]
	self.message:setPosition(PADDING_X, title_bottom + GAP)
	local message_bottom = title_bottom + GAP + self.message.offset_max[2] - self.message.offset_min[2]
	self.url_label:setPosition(PADDING_X, message_bottom + GAP)
	local url_bottom = message_bottom + GAP + self.url_label.offset_max[2] - self.url_label.offset_min[2]
	self.actions:setAlignment(0.5, 0):addPosition(0, url_bottom + GAP)

	local content_width = math.max(
		self.title.offset_max[1] - self.title.offset_min[1],
		self.message.offset_max[1] - self.message.offset_min[1],
		self.url_label.offset_max[1] - self.url_label.offset_min[1],
		self.actions.offset_max[1] - self.actions.offset_min[1]
	)
	local height = url_bottom + GAP + self.actions.offset_max[2] - self.actions.offset_min[2] + PADDING_BOTTOM
	self:setSize(math.max(MIN_WIDTH, content_width + PADDING_X * 2), height)
end

function ExternalLink:show()
	self:setVisible(true)
	self:fadeIn(0.25, "OutCubic")
end

function ExternalLink:hide()
	self:transformTo("opacity", 0, 0.18, "InCubic", function()
		self:setVisible(false)
	end)
end

function ExternalLink:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return ExternalLink
