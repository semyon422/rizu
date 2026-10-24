local View = require("gui.View")
local Label = require("ui.views.Label")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Rectangle = require("ui.views.Rectangle")
local ScrollView = require("gui.ScrollView")
local FlowContainer = require("gui.layout.FlowContainer")
local EditorButton = require("ui.views.editor.EditorButton")
local EditorCheckbox = require("ui.views.editor.EditorCheckbox")
local EditorDropdown = require("ui.views.editor.EditorDropdown")
local EditorGroupHeader = require("ui.views.editor.EditorGroupHeader")
local EditorList = require("ui.views.editor.EditorList")
local EditorSlider = require("ui.views.editor.EditorSlider")
local PopupContainer = require("ui.views.PopupContainer")

---The gameplay skin editor: a panel on the left with what there is to edit and the properties of
---the selected section, and a frame around the shrunk gameplay window.
---@class ui.screens.gameplay.SkinEditor : gui.View
---@operator call: ui.screens.gameplay.SkinEditor
---@field ui ui.UserInterface
---@field gameplay rizu.api.Gameplay
---@field panel ui.views.Rectangle
---@field frame gui.View Covers the window around the shrunk gameplay and outlines it.
---@field sections ui.views.editor.EditorList What there is to edit.
---@field add_button ui.views.editor.EditorButton
---@field reset_button ui.views.editor.EditorButton
---@field scroll gui.ScrollView Properties of the selected section.
---@field section_list rizu.api.Gameplay.SkinSection[]
---@field section_id string? The section to show.
---@field shown_id string? The section shown now.
---@field controls gui.layout.FlowContainer
---@field status ui.views.Label
---@field popup ui.views.PopupContainer
---@field refresh_pending boolean?
local SkinEditor = View + {}

local WIDTH = 420 -- UI units
local PADDING = 12
local CONTROL_WIDTH = WIDTH - PADDING * 2
local HEADER_HEIGHT = 40
local TITLE_HEIGHT = 40
local MARGIN = 16 -- around the shrunk gameplay
local SPLIT = 0.4 -- of the panel height for the section list

---@param ui ui.UserInterface
function SkinEditor:new(ui)
	View.new(self)
	self.ui = ui
	self.gameplay = ui.api.gameplay
	self:anchorFill(0, 0, 0, 0)
	self:setVisible(false)

	self.frame = self:add(View()):anchorFill(0, 0, 0, 0)
	self.frame:setDraw(function() self:drawFrame() end)
	self.panel = self:add(Rectangle(Colors.panel))
	self.panel:anchorFixed(0, 0, WIDTH, 0):fillHeight(0, 0)
	self.panel:add(Rectangle(Colors.outline)):anchorFixed(WIDTH - 1, 0, 1, 0):fillHeight(0, 0)
	local localization = ui.localization
	local sections = self.panel:add(View()):anchorPercent(0, 0, 1, SPLIT)
	local sections_header = self:addHeader(sections, localization:get("gameplay.skin_editor.elements"))
	self.reset_button = self:addHeaderButton(sections_header,
		localization:get("gameplay.skin_editor.reset"), WIDTH - 4, function()
			self.gameplay:resetHudLayout()
			self.section_id = nil
			self.refresh_pending = true
		end)
	self.add_button = self:addHeaderButton(sections_header,
		localization:get("gameplay.skin_editor.add"), self.reset_button.offset_min[1] - 2, function()
			self.ui.modal_manager:attachHudElementPicker(function(id)
				self.section_id = id
				self.refresh_pending = true
			end)
		end)
	self.sections = sections:add(EditorList(function(index)
		local section = self.section_list[index]
		if not section then return end
		self.section_id = section.id
		self.refresh_pending = true
	end))
	self.sections:anchorFill(0, HEADER_HEIGHT + 4, 1, 4)
	self.section_list = {}
	self.section_id = nil
	local properties = self.panel:add(View()):anchorPercent(0, SPLIT, 1, 1)
	properties:add(Rectangle(Colors.outline)):anchorFixed(0, 0, WIDTH - 1, 1)
	self:addHeader(properties, localization:get("gameplay.skin_editor.inspector")):setPosition(0, 1)
	self.scroll = properties:add(ScrollView())
	self.scroll:anchorFill(PADDING, HEADER_HEIGHT + 1, PADDING, PADDING)
	self.scroll.content:anchorFixed(0, 0, CONTROL_WIDTH, 0)
	self.controls = self.scroll.content:add(FlowContainer({direction = "column", gap = 4}))
	self.status = self.controls:add(Label({
		font_name = "regular", font_size = 14, text = "",
	}))
	-- Dropdown popups must escape the scroll view's clipping, so they live above the panel.
	self.popup = self:add(PopupContainer())
end

---The editor panel takes the left side. The window as the player sees it shrinks into the rest,
---centered with a margin and keeping its aspect ratio.
---@param width number Window size in drawable pixels.
---@param height number
---@param ui_scale number
---@return number x Of the shrunk window, in drawable pixels.
---@return number y
---@return number scale
function SkinEditor.getWindow(width, height, ui_scale)
	local panel = WIDTH * ui_scale
	local margin = MARGIN * ui_scale
	local scale = math.max(0, math.min(
		(width - panel - margin * 2) / width,
		(height - margin * 2) / height
	))
	return panel + (width - panel - width * scale) / 2, (height - height * scale) / 2, scale
end

function SkinEditor:open()
	self:setVisible(true)
	self:refresh()
end

function SkinEditor:close()
	self:closePopup()
	self:setVisible(false)
end

function SkinEditor:drawFrame()
	local screen = self.screen
	if not screen or screen.width <= 0 then return end
	local screen_width, screen_height = screen.width, screen.height
	local x, y, scale = SkinEditor.getWindow(screen_width, screen_height, screen.ui_scale)
	local width, height = screen_width * scale, screen_height * scale
	local right, bottom = x + width, y + height
	local lg = love.graphics
	lg.push("all")
	lg.scale(1 / screen.ui_scale)
	Painter.setColorTable(Colors.background)
	lg.rectangle("fill", 0, 0, screen_width, y)
	lg.rectangle("fill", 0, bottom, screen_width, screen_height - bottom)
	lg.rectangle("fill", 0, y, x, height)
	lg.rectangle("fill", right, y, screen_width - right, height)
	Painter.setColorTable(Colors.outline)
	lg.setLineWidth(1)
	lg.rectangle("line", x - 0.5, y - 0.5, width + 1, height + 1)
	lg.pop()
end

---A dark bar with a title at the top of an editor dock.
---@param dock gui.View
---@param title string
---@return gui.View
function SkinEditor:addHeader(dock, title)
	local header = dock:add(Rectangle(Colors.background))
	header:anchorFixed(0, 0, WIDTH - 1, HEADER_HEIGHT)
	local label = header:add(Label({font_name = "medium", font_size = 16, text = title}))
	label:setPosition(PADDING, math.floor((HEADER_HEIGHT - label:getAuthoredHeight()) / 2))
	return header
end

---@param header gui.View
---@param text string
---@param right number Where the button ends.
---@param on_click fun()
---@return ui.views.editor.EditorButton
function SkinEditor:addHeaderButton(header, text, right, on_click)
	local button = header:add(EditorButton({text = text, variant = "ghost", on_click = on_click}))
	local width, height = button:getAuthoredSize()
	button:anchorFixed(right - width, math.floor((HEADER_HEIGHT - height) / 2), width, height)
	return button
end

---Closes an open dropdown popup, if any.
function SkinEditor:closePopup()
	local owner = self.popup.owner
	if owner then owner:close() end
end

---@param property rizu.api.Gameplay.SkinProperty
---@return gui.View
function SkinEditor:createControl(property)
	local label = property.label or self.ui.localization:get(property.label_key)
	-- Changes reach the file when gameplay closes: writing it on every slider step lags.
	local function commit(value)
		property.set(value)
		-- Not now: the control that changed may be among the ones a refresh replaces.
		if property.refresh then self.refresh_pending = true end
	end

	local control_type = property.type or "slider"
	local value = property.get()
	if control_type == "texture" then
		local format = property.format or tostring
		return EditorButton({label = label, text = format(value), width = CONTROL_WIDTH, on_click = function()
			self.ui.modal_manager:attachTexturePicker(property, commit)
		end})
	elseif control_type == "checkbox" then
		return EditorCheckbox({label = label, checked = value, width = CONTROL_WIDTH, on_change = commit})
	elseif control_type == "segmented" or control_type == "dropdown" then
		return EditorDropdown({
			label = label,
			options = property.options or {},
			value = value,
			width = CONTROL_WIDTH,
			format = property.format,
			popup_container = self.popup,
			on_change = commit,
		})
	end
	return EditorSlider({
		label = label,
		value = value,
		min = property.min or 0,
		max = property.max or 1,
		step = property.step,
		width = CONTROL_WIDTH,
		fill_color = property.fill_color,
		value_format = property.value_format or function(value) return tostring(math.floor(value + 0.5)) end,
		on_change = commit,
	})
end

---The section name, and a button to remove it when it can be removed.
---@param section rizu.api.Gameplay.SkinSection
---@return gui.View
function SkinEditor:createTitle(section)
	local row = View()
	row:setSize(CONTROL_WIDTH, TITLE_HEIGHT)
	local title = row:add(Label({font_name = "medium", font_size = 16, text = section.label}))
	title:setPosition(0, math.floor((TITLE_HEIGHT - title:getAuthoredHeight()) / 2))
	local remove = section.remove
	if remove then
		local button = row:add(EditorButton({
			text = self.ui.localization:get("gameplay.skin_editor.remove"),
			variant = "danger",
			on_click = function()
				remove()
				self.section_id = nil
				self.refresh_pending = true
			end,
		}))
		local width, height = button:getAuthoredSize()
		button:setPosition(CONTROL_WIDTH - width, math.floor((TITLE_HEIGHT - height) / 2))
	end
	return row
end

function SkinEditor:updateContentHeight()
	-- FlowContainer:fitContent() updates authored dimensions, while `height`
	-- remains the previous resolved layout value until the next screen flush.
	-- Measure the flow directly so the ScrollView gets the complete content
	-- extent immediately.
	local _, content_height = self.controls:getContentSize()
	self.scroll.content:setHeight(content_height)
end

function SkinEditor:refresh()
	self:closePopup()
	local sections = self.gameplay:getSkinSections() or {}
	self.section_list = sections
	local items = {} ---@type ui.views.editor.EditorList.Item[]
	local selected ---@type rizu.api.Gameplay.SkinSection?
	for i, section in ipairs(sections) do
		items[i] = {name = section.label, id = section.id}
		if section.id == self.section_id then selected = section end
	end
	selected = selected or sections[1]
	local selected_id = selected and selected.id
	-- Another section starts at the top; the same one keeps its place after an edit.
	if selected_id ~= self.shown_id then self.scroll:scrollTo(0, true) end
	self.section_id, self.shown_id = selected_id, selected_id
	self.sections:setItems(items, self.section_id)
	local has_hud = #self.gameplay:getHudLayers() > 0
	self.add_button:setEnabled(has_hud)
	self.reset_button:setEnabled(has_hud)

	self.controls:clear()
	self.controls:setDirection("column")
	self.controls:setGap(4)
	if not selected then
		self.status:setText(self.ui.localization:get("gameplay.skin_editor.no_properties"))
		self.status:setSize(CONTROL_WIDTH, 24)
		self.controls:add(self.status)
	else
		self.controls:add(self:createTitle(selected))
		local group ---@type string?
		for _, property in ipairs(selected.properties) do
			if property.group and property.group ~= group then
				group = property.group
				self.controls:add(EditorGroupHeader(group, CONTROL_WIDTH))
			end
			self.controls:add(self:createControl(property))
		end
	end
	self.controls:fitContent()
	self:updateContentHeight()
end

---@param dt number
function SkinEditor:update(dt)
	if self.refresh_pending then
		self.refresh_pending = false
		self:refresh()
	end
end

return SkinEditor
