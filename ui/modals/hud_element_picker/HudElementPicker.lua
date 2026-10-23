local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local RadioList = require("ui.views.RadioList")
local Resources = require("ui.Resources")
local SegmentedControl = require("ui.views.form.SegmentedControl")
local UiActions = require("ui.UiActions")

---Picks a HUD element type and the layer to add it to, for the skin editor.
---@class ui.modals.hud_element_picker.HudElementPicker : ui.ModalView
---@operator call: ui.modals.hud_element_picker.HudElementPicker
---@field gameplay rizu.api.Gameplay
---@field types rizu.api.Gameplay.HudElementType[]
---@field layers rizu.api.Gameplay.HudLayer[]
---@field selected_index integer
---@field layer rizu.skin.hud.HudLayout.Layer?
---@field layer_control ui.views.form.SegmentedControl?
---@field on_added fun(id: string)?
local HudElementPicker = ModalView + {}

local WIDTH = 640
local HEIGHT = 760
local CONTENT_X = 28
local HEADER_HEIGHT = 112
local FOOTER_HEIGHT = 92
local LAYER_HEIGHT = 65
local GAP = 20

---@param gameplay rizu.api.Gameplay
---@param on_close fun()
---@param localization ui.localization.Localization
function HudElementPicker:new(gameplay, on_close, localization)
	ModalView.new(self)
	self.gameplay = gameplay
	self.localization = localization
	self.on_close = on_close
	self.types = {}
	self.layers = {}
	self.selected_index = 1
	self.layer = nil

	self:setSize(WIDTH, HEIGHT):setAlignment(0.5, 0.5):setPivot(0.5, 0.5)
	self:setOpacity(0):setVisible(false):setClip(true)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt, sprites.nineslice_modal_t, sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l, sprites.nineslice_modal_c, sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb, sprites.nineslice_modal_b, sprites.nineslice_modal_rb,
	})

	self:add(ModalHeader(localization:get("gameplay.skin_editor.add_title"),
		localization:get("gameplay.skin_editor.add_subtitle")))
	self.list = self:add(RadioList(function(index) self:select(index) end))
	self:add(ModalFooter(on_close, localization:get("settings.close")))
	self.add_button = self:add(Button(localization:get("gameplay.skin_editor.add"), function()
		self:confirm()
	end, {variant = "primary", shape = "capsule", font_size = 18}))
	self.add_button:setSize(150, 48):setPosition(WIDTH - CONTENT_X - 150, HEIGHT - 70)
end

---@param on_added fun(id: string) Gets the editor section id of the new element.
function HudElementPicker:open(on_added)
	self.on_added = on_added
	self.types = self.gameplay:getHudElementTypes()
	self.layers = self.gameplay:getHudLayers()
	self.layer = self.layers[1] and self.layers[1].name

	if self.layer_control then
		self:remove(self.layer_control)
		self.layer_control = nil
	end
	local list_y = HEADER_HEIGHT + GAP
	-- Only renderers with a conveyor have a choice to make.
	if #self.layers > 1 then
		local names = {} ---@type rizu.skin.hud.HudLayout.Layer[]
		local labels = {} ---@type {[string]: string}
		for i, layer in ipairs(self.layers) do
			names[i], labels[layer.name] = layer.name, layer.label
		end
		self.layer_control = self:add(self:newLayerControl({
			label = self.localization:get("gameplay.skin_editor.layer"),
			options = names,
			value = self.layer,
			format = function(name) return labels[name] end,
			on_change = function(name) self.layer = name end,
		}))
		self.layer_control:setPosition(CONTENT_X, list_y)
		list_y = list_y + LAYER_HEIGHT + GAP
	end
	self.list:anchorFixed(CONTENT_X, list_y, WIDTH - CONTENT_X * 2, HEIGHT - FOOTER_HEIGHT - GAP - list_y)

	local items = {} ---@type ui.views.RadioList.Item[]
	for i, element_type in ipairs(self.types) do items[i] = {name = element_type.label, path = element_type.name} end
	self.selected_index = 1
	self.list:setItems(items, items[1] and items[1].path)
	self.add_button:setEnabled(#items > 0 and self.layer ~= nil)
end

---@param params ui.views.form.SegmentedControlParams
---@return ui.views.form.SegmentedControl
function HudElementPicker:newLayerControl(params)
	return SegmentedControl(params)
end

---@param index integer
function HudElementPicker:select(index)
	local element_type = self.types[index]
	if not element_type then return end
	self.selected_index = index
	self.list.selected_path = element_type.name
end

function HudElementPicker:confirm()
	local element_type = self.types[self.selected_index]
	if not element_type or not self.layer then return end
	local id = self.gameplay:addHudElement(element_type.name, self.layer)
	self.on_close()
	if self.on_added then self.on_added(id) end
end

---@param offset integer
function HudElementPicker:move(offset)
	if #self.types == 0 then return end
	self:select((self.selected_index - 1 + offset) % #self.types + 1)
	local top = (self.selected_index - 1) * self.list:getRowStep()
	self.list:scrollTo(top + self.list.item_height / 2 - self.list.height / 2)
end

---@param inputs gui.Inputs
function HudElementPicker:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.down) then
		self:move(1)
	elseif inputs:consumeActionJustPressed(UiActions.up) then
		self:move(-1)
	elseif inputs:consumeActionJustPressed(UiActions.accept) then
		self:confirm()
	end
end

function HudElementPicker:show()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function HudElementPicker:hide()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function HudElementPicker:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return HudElementPicker
