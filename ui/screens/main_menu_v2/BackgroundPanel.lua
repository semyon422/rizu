local BackgroundLayers = require("ui.screens.main_menu_v2.BackgroundLayers")
local Colors = require("ui.Colors")
local ControlFactory = require("ui.modals.config.rows.RowFactory")
local FilePicker = require("rizu.files.FilePicker")
local Form = require("ui.views.form.Form")
local HeaderButton = require("ui.screens.song_select_v2.HeaderButton")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local LayerRow = require("ui.screens.main_menu_v2.LayerRow")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local UiActions = require("ui.UiActions")
local UiConfig = require("ui.UiConfig")
local View = require("gui.View")

---Picks the main menu background layers, in the settings modal's look. It is not a modal: the background
---stays undimmed next to it, so every change shows as it is made.
---@class ui.screens.main_menu_v2.BackgroundPanel : gui.View
---@operator call: ui.screens.main_menu_v2.BackgroundPanel
---@field layers ui.screens.main_menu_v2.BackgroundLayers
---@field localization ui.localization.Localization
---@field notifications rizu.api.Notifications
---@field file_picker rizu.files.FilePicker
---@field form ui.views.form.Form
---@field scroll_view gui.ScrollView
---@field background gui.NineSliceUsage
---@field is_open boolean
---@field private invalidated boolean
local BackgroundPanel = View + {}

BackgroundPanel.WIDTH = 560
BackgroundPanel.HEIGHT = 700
local HEADER_HEIGHT = 64
local PADDING = 16
local GROUP_GAP = 16
local ROW_WIDTH = BackgroundPanel.WIDTH - PADDING * 2
local NO_MODIFIERS = {control = false, shift = false, alt = false, super = false}

---@param layers ui.screens.main_menu_v2.BackgroundLayers
---@param localization ui.localization.Localization
---@param notifications rizu.api.Notifications
---@param file_picker rizu.files.FilePicker?
function BackgroundPanel:new(layers, localization, notifications, file_picker)
	View.new(self)
	self.layers = layers
	self.localization = localization
	self.notifications = notifications
	self.file_picker = file_picker or FilePicker()
	self.is_open = false
	self.invalidated = false
	self.handles_mouse_input = true
	self:setSize(BackgroundPanel.WIDTH, BackgroundPanel.HEIGHT)
	self:setOpacity(0)
	self:setVisible(false)
	self.background = NineSliceUsage(Resources.nine_slices.config_v2_modal)

	self:add(Image(Resources.sprites.icon_image, "fit", Colors.accent)):anchorFixed(PADDING + 8, 22, 20, 20)
	local title = self:add(Label({font_name = "bold", font_size = 22, text = localization:get("main_menu.background")}))
	title:setOffset(PADDING + 38, math.floor((HEADER_HEIGHT - title:getAuthoredHeight()) / 2))
	local close = self:add(HeaderButton(Resources.sprites.icon_x, function() self:close() end))
	close:setPosition(BackgroundPanel.WIDTH - PADDING - 42, (HEADER_HEIGHT - 50) / 2)

	self.form = Form({direction = "column", padding = {PADDING, PADDING, PADDING, PADDING}})
	self.scroll_view = self:add(ScrollView(self.form))
	self.scroll_view:anchorFixed(1, HEADER_HEIGHT, BackgroundPanel.WIDTH - 2, BackgroundPanel.HEIGHT - HEADER_HEIGHT - 1)
	self:rebuild()
end

---@param value number
---@return string
local function formatPixels(value)
	return ("%d px"):format(value)
end

---@param value number
---@return string
local function formatDepth(value)
	return ("×%.1f"):format(value)
end

---@private
---@param name ui.screens.main_menu_v2.BackgroundLayers.Name
---@return gui.View[] rows
function BackgroundPanel:createLayerRows(name)
	local layers, localization = self.layers, self.localization
	local config = layers.config
	local path = layers:getPath(name)
	local none = path == BackgroundLayers.NONE
	local file_name = path == "" and localization:get("main_menu.background_default")
		or none and localization:get("main_menu.background_empty")
		or path:match("[^/]+$")
	---@type ui.views.form.ButtonRow.Button[]
	local buttons = {{text = localization:get("main_menu.background_choose"), on_click = function() self:pick(name) end}}
	if path ~= "" then
		buttons[#buttons + 1] = {text = localization:get("main_menu.background_reset"), on_click = function()
			layers:reset(name)
			self.invalidated = true
		end}
	end
	-- An empty back layer would leave the menu on black.
	if not none and name ~= "back" then
		buttons[#buttons + 1] = {text = localization:get("main_menu.background_remove"), on_click = function()
			layers:remove(name)
			self.invalidated = true
		end}
	end
	return {
		LayerRow(localization:get("main_menu.background_" .. name), file_name, layers:getImage(name), buttons),
		ControlFactory.number(config, BackgroundLayers.key(name, "depth"), {
			name = localization:get("main_menu.background_depth"),
			value_format = formatDepth,
		}),
		ControlFactory.segmentedChoice(config, BackgroundLayers.key(name, "fit"), {
			name = localization:get("main_menu.background_fit"),
			format = function(value) return localization:get("main_menu.background_" .. value) end,
		}),
	}
end

---@private
function BackgroundPanel:rebuild()
	self.invalidated = false
	local form = self.form
	form:clearSelection()
	form:clearRows()
	---@type gui.View[][]
	local groups = {{ControlFactory.number(self.layers.config, UiConfig.keys.main_menu_parallax, {
		name = self.localization:get("main_menu.background_parallax"),
		value_format = formatPixels,
	})}}
	-- Front first, as layers stack in an image editor.
	for i = #BackgroundLayers.names, 1, -1 do
		groups[#groups + 1] = self:createLayerRows(BackgroundLayers.names[i])
	end
	for index, rows in ipairs(groups) do
		if index > 1 then
			form:add(View():setSize(ROW_WIDTH, GROUP_GAP))
		end
		for i, row in ipairs(rows) do
			---@cast row gui.View|{setting_row: ui.modals.config.rows.SettingRow}
			row:setWidth(ROW_WIDTH)
			row.setting_row:place(form, i == 1, i == #rows)
			form:add(row)
		end
	end
	form:fitContent()
end

---@private
---@param name ui.screens.main_menu_v2.BackgroundLayers.Name
function BackgroundPanel:pick(name)
	local localization = self.localization
	local title = localization:get("main_menu.background_dialog_title")
	self.file_picker:open(title, {["Images"] = "png;jpg;jpeg"}, function(path, err)
		if path then
			local ok
			ok, err = self.layers:import(name, path)
			if ok then
				-- Rows are rebuilt in update(), not inside the click or dialog callback that led here.
				self.invalidated = true
				return
			end
		end
		if err then
			self.notifications:post("error", "main_menu_background", localization:get("main_menu.background_load_failed"), err)
		end
	end)
end

function BackgroundPanel:open()
	if self.is_open then return end
	self.is_open = true
	self:setVisible(true)
	self:fadeIn(0.2, "OutCubic")
	local inputs = self.screen and self.screen.inputs
	if inputs then
		inputs:pushFocusScope(self)
		inputs:setKeyboardFocus(self.form, NO_MODIFIERS)
	end
end

function BackgroundPanel:close()
	if not self.is_open then return end
	self.is_open = false
	self.layers.config:save()
	local inputs = self.screen and self.screen.inputs
	if inputs then
		inputs:setKeyboardFocus(nil, NO_MODIFIERS)
		inputs:popFocusScope(self)
	end
	self:transformTo("opacity", 0, 0.15, "InCubic", function()
		self:setVisible(false)
	end)
end

function BackgroundPanel:toggle()
	if self.is_open then self:close() else self:open() end
end

---@param dt number
function BackgroundPanel:update(dt)
	if self.invalidated then
		self:rebuild()
	end
end

---@param inputs gui.Inputs
function BackgroundPanel:onHandleInputs(inputs)
	if self.is_open and inputs:consumeActionJustPressed(UiActions.cancel) then
		self:close()
	end
end

---Clicks on the panel do not reach the menu under it.
---@return boolean handled
function BackgroundPanel:onMouseDown()
	return true
end

function BackgroundPanel:draw()
	Painter.setColorRgb(1, 1, 1, 1)
	self.background:draw(self.width, self.height)
	Painter.setColorTable(Colors.divider)
	Resources.sprites.pixel:draw(1, HEADER_HEIGHT - 1, 0, self.width - 2, 1)
end

return BackgroundPanel
