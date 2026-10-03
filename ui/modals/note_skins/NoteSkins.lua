local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local NoteSkinList = require("ui.modals.note_skins.NoteSkinList")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Settings = require("rizu.config.Settings")
local UiActions = require("ui.UiActions")
local View = require("gui.View")

---@class ui.modals.note_skins.NoteSkins.ConfigView : gui.View
---@operator call: ui.modals.note_skins.NoteSkins.ConfigView
local ConfigView = View + {}

local CONFIG_WINDOW_ID = "NoteSkinOverrides"
local CONFIG_PALETTE = {
	control = Colors.surface_raised,
	control_hover = Colors.outline,
	control_active = Colors.accent,
	boundless_hover = Colors.surface_raised,
	boundless_active = Colors.outline,
	text = Colors.text,
	muted = Colors.muted,
	accent = Colors.accent,
	divider = Colors.divider,
	scrollbar_track = Colors.surface,
	scrollbar_thumb = Colors.outline,
	scrollbar_thumb_hover = Colors.muted,
}

function ConfigView:new()
	View.new(self)
	self.config = nil
	self.scroll_y = 0
	self:setClip(true)
	self.handles_mouse_input = true
end

---@param config sphere.JustConfig?
function ConfigView:setConfig(config)
	self.config = config
	self.scroll_y = 0
end

function ConfigView:onMouseDown()
	return true
end

function ConfigView:onMouseUp()
	return true
end

function ConfigView:onMouseClick()
	return true
end

function ConfigView:onScroll()
	return true
end

function ConfigView:draw()
	local config = self.config
	if not config or not config.draw then return end
	local imgui = require("imgui")
	local just = require("just")
	local theme = require("imgui.theme")

	-- Skin configs are legacy immediate-mode UIs authored in drawable pixels.
	-- Cancel the retained UI's root scale and give them the resulting pixel size.
	local ui_scale = assert(self.screen).ui_scale
	local width, height = self.width * ui_scale, self.height * ui_scale
	love.graphics.push("all")
	love.graphics.scale(1 / ui_scale)
	theme.pushPalette(CONFIG_PALETTE)
	just.push()
	imgui.Container(CONFIG_WINDOW_ID, width, height, 12, 55, self.scroll_y)
	config:draw(width, height)
	self.scroll_y = imgui.Container()
	just.pop()
	theme.popPalette()
	love.graphics.pop()
end

---@class ui.modals.note_skins.NoteSkins : ui.ModalView
---@operator call: ui.modals.note_skins.NoteSkins
---@field items (rizu.skin.SkinInfo|rizu.skin.OsuSkinDiscovery|rizu.skin.StepmaniaSkinDiscovery)[]
---@field input_mode string
---@field is_osu_mode boolean
---@field osu_skin_setting_key string?
local NoteSkins = ModalView + {}

local WIDTH = 920
local HEIGHT = 800
local CONTENT_X = 28
local HEADER_HEIGHT = 112
local FOOTER_HEIGHT = 92
local CONTENT_PADDING_Y = 20
local RIZU_DEFAULT_SKIN_PATH = "rizu/skin/base/rizu_mania.skin.lua"

---@param skin rizu.skin.SkinInfo
---@return boolean
local function isRizuDefaultSkin(skin)
	return skin.path == RIZU_DEFAULT_SKIN_PATH
end

---@param game sphere.GameController
---@param on_close fun()
---@param localization ui.localization.Localization
---@param on_edit fun()?
function NoteSkins:new(game, on_close, localization, on_edit)
	ModalView.new(self)
	self.localization = localization
	self.game = game
	self.on_edit = on_edit
	self.input_mode = ""
	self.is_osu_mode = false
	self.osu_skin_setting_key = nil
	self.items = {}
	self.selected_index = 1
	self.page = "list"
	self.edited_note_skin = nil

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

	self.list_page = self:add(View())
	self.list_page:anchorFill(0, 0, 0, 0)
	self.list_header = self.list_page:add(ModalHeader(localization:get("song_select.note_skins_title"),
		localization:get("song_select.note_skins_subtitle")))
	self.list = self.list_page:add(NoteSkinList(function(index) self:select(index) end,
		localization:get("song_select.no_compatible_skins")))
	self.list:anchorFixed(CONTENT_X, HEADER_HEIGHT + CONTENT_PADDING_Y,
		WIDTH - CONTENT_X * 2, HEIGHT - HEADER_HEIGHT - FOOTER_HEIGHT - CONTENT_PADDING_Y * 2)
	self.list_page:add(ModalFooter(on_close, localization:get("settings.close")))
	self.edit_button = self.list_page:add(Button(localization:get("note_skin_overrides.edit"), function()
		self:editSkin()
	end, {variant = "primary", shape = "capsule", font_size = 18}))
	self.edit_button:setSize(150, 48):setPosition(WIDTH - CONTENT_X - 150, HEIGHT - 70)

	self.overrides_page = self:add(View())
	self.overrides_page:anchorFill(0, 0, 0, 0)
	self.overrides_page:add(ModalHeader(localization:get("note_skin_overrides.title"),
		localization:get("note_skin_overrides.subtitle")))
	self.config_view = self.overrides_page:add(ConfigView())
	self.config_view:anchorFixed(CONTENT_X, HEADER_HEIGHT + CONTENT_PADDING_Y,
		WIDTH - CONTENT_X * 2, HEIGHT - HEADER_HEIGHT - FOOTER_HEIGHT - CONTENT_PADDING_Y * 2)
	self.overrides_page:add(ModalFooter(function() self:showList() end,
		localization:get("note_skin_overrides.back")))
	self.overrides_page:setVisible(false):setEnabled(false)
end

function NoteSkins:refresh()
	local input_mode = tostring(self.game.modifierCoordinator.state.inputMode or "")
	self.input_mode = input_mode
	local chart_selector = self.game.chartSelector
	local chartview = chart_selector and chart_selector.chartview
	local has_chart = chartview ~= nil
	if chart_selector and chart_selector.isPlayableChartview then
		has_chart = chart_selector:isPlayableChartview(chartview)
	end
	if not has_chart then
		self.is_osu_mode = false
		self.osu_skin_setting_key = nil
		self.items = {}
		self.selected_index = 1
		self.list_header.subtitle:setText(self.localization:get("song_select.select_chart_for_skin"))
		self.list:setItems({}, nil)
		self.edit_button:setEnabled(false)
		return
	end
	local chartmeta_mode = chartview and chartview.chartmeta_mode
	local osu_skin_mode = ({
		osu = "1osu",
		taiko = "1taiko",
		catch = "1fruits",
	})[chartmeta_mode]
	self.is_osu_mode = osu_skin_mode ~= nil
	self.osu_skin_setting_key = osu_skin_mode and ("osu/" .. osu_skin_mode) or nil
	if input_mode == "" and not self.is_osu_mode then
		self.items = {}
		self.selected_index = 1
		self.list_header.subtitle:setText(self.localization:get("song_select.select_chart_for_skin"))
		self.list:setItems({}, nil)
		self.edit_button:setEnabled(false)
		return
	end

	local registry = self.game.skinRegistry
	self.items = {}
	if self.is_osu_mode then
		if registry then
			for _, skin in ipairs(registry:getSkins()) do
				local metadata = skin.metadata
				local compatible = isRizuDefaultSkin(skin)
				if metadata and metadata.gamemode == "mania" then
					for _, supported_input_mode in ipairs(metadata.input_modes) do
						if supported_input_mode == input_mode or supported_input_mode == "any" then
							compatible = true
							break
						end
					end
				end
				if compatible then table.insert(self.items, skin) end
			end
			for _, skin in ipairs(registry:getOsuSkins()) do
				table.insert(self.items, skin)
			end
		end
		local skin_paths = self.game.settings:getStringMap(Settings.keys.gameplay.skins)
		local selected_path = skin_paths[self.osu_skin_setting_key] or skin_paths["osu/1osu"] or skin_paths.osu
		local normalized_path = selected_path and selected_path:gsub("\\", "/"):gsub("/+$", "")
		local selected
		for _, skin in ipairs(self.items) do
			if skin.path == normalized_path then
				selected = skin
				break
			end
		end
		if not selected then
			selected = self.items[1]
			if selected then
				if selected.format == "osu" then
					skin_paths[self.osu_skin_setting_key] = selected.path
				else
					skin_paths["mania/" .. input_mode] = selected.path
					skin_paths[self.osu_skin_setting_key] = nil
				end
				self.game.settings:setStringMap(Settings.keys.gameplay.skins, skin_paths)
			end
		end
		selected_path = selected and selected.path or nil
		self.list_header.subtitle:setText(self.localization:get("song_select.osu_skin"))
		self.selected_index = 1
		for index, item in ipairs(self.items) do
			if item.path == selected_path then
				self.selected_index = index
				break
			end
		end
		self.list:setItems(self.items, selected_path)
		self.edit_button:setEnabled(false)
		return
	end
	if registry then
		for _, skin in ipairs(registry:getSkins()) do
			local metadata = skin.metadata
			local compatible = isRizuDefaultSkin(skin)
			if metadata and metadata.gamemode == "mania" then
				for _, supported_input_mode in ipairs(metadata.input_modes) do
					if supported_input_mode == input_mode or supported_input_mode == "any" then
						compatible = true
						break
					end
				end
			end
			if compatible then table.insert(self.items, skin) end
		end
		for _, skin in ipairs(registry:getOsuSkins()) do
			table.insert(self.items, skin)
		end
	end

	local skin_paths = self.game.settings:getStringMap(Settings.keys.gameplay.skins)
	---@type string?
	local selected_path = skin_paths["mania/" .. input_mode]
		or skin_paths["osu/1osu"] or skin_paths.osu
	local selected = selected_path and registry and registry:getSkinForInputMode("mania", input_mode, selected_path)
	selected = selected or (registry and registry:getOsuSkins()[1])
	selected_path = selected and selected.path or nil
	self.list_header.subtitle:setText(self.localization:get("song_select.choose_skin_for") .. input_mode .. ".")
	self.selected_index = 1
	for index, item in ipairs(self.items) do
		if item.path == selected_path then
			self.selected_index = index
			break
		end
	end
	self.list:setItems(self.items, selected_path)
	self.edit_button:setEnabled(selected ~= nil)
end

---@param index integer
function NoteSkins:select(index)
	local item = self.items[index]
	if not item or (self.input_mode == "" and not self.osu_skin_setting_key) then return end
	self.selected_index = index
	local skin_paths = self.game.settings:getStringMap(Settings.keys.gameplay.skins)
	if self.is_osu_mode and item.format == "osu" then
		skin_paths[self.osu_skin_setting_key] = item.path
	elseif self.is_osu_mode then
		skin_paths["mania/" .. self.input_mode] = item.path
		skin_paths[self.osu_skin_setting_key] = nil
	else
		skin_paths["mania/" .. self.input_mode] = item.path
	end
	self.game.settings:setStringMap(Settings.keys.gameplay.skins, skin_paths)
	self.list.selected_path = item.path
	self.edit_button:setEnabled(not self.is_osu_mode)
end

function NoteSkins:editSkin()
	local selected = self.items[self.selected_index]
	if self.is_osu_mode or self.input_mode == "" or #self.items == 0 then return end
	if self.on_edit then
		self.on_edit()
	end
end

function NoteSkins:showOverrides()
	local selected = self.items[self.selected_index]
	if self.is_osu_mode or self.input_mode == "" or selected and selected.format == "osu" then return end
	local note_skin = self.game.noteSkinModel.noteSkin
	if not note_skin or not note_skin.config then return end
	self.page = "overrides"
	self.edited_note_skin = note_skin
	self.config_view:setConfig(note_skin.config)
	self.list_page:setVisible(false):setEnabled(false)
	self.overrides_page:setVisible(true):setEnabled(true)
end

function NoteSkins:showList()
	if self.page ~= "overrides" then return end
	local note_skin = self.edited_note_skin
	if note_skin and note_skin.config then
		note_skin.config:close()
	end
	if self.input_mode ~= "" and not self.is_osu_mode then
		self.game.noteSkinModel:loadNoteSkin(self.input_mode)
	end
	self.edited_note_skin = nil
	self.config_view:setConfig(nil)
	self.page = "list"
	self.overrides_page:setVisible(false):setEnabled(false)
	self.list_page:setVisible(true):setEnabled(true)
	self:refresh()
end

---@param offset integer
function NoteSkins:move(offset)
	if #self.items == 0 then return end
	self.selected_index = ((self.selected_index - 1 + offset) % #self.items) + 1
	self:select(self.selected_index)
	local top = (self.selected_index - 1) * self.list:getRowStep()
	self.list:scrollTo(top + self.list.item_height / 2 - self.list.height / 2)
end

---@param inputs gui.Inputs
function NoteSkins:onHandleInputs(inputs)
	if self.page == "overrides" then
		if inputs:consumeActionJustPressed(UiActions.cancel) then
			self:showList()
		end
		return
	end
	if inputs:consumeActionJustPressed(UiActions.down) then
		self:move(1)
	elseif inputs:consumeActionJustPressed(UiActions.up) then
		self:move(-1)
	end
end

function NoteSkins:show()
	self:refresh()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function NoteSkins:hide()
	if self.page == "overrides" then
		self:showList()
	end
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function NoteSkins:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return NoteSkins
