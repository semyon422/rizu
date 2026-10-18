local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local FilePicker = require("rizu.files.FilePicker")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Textbox = require("ui.views.form.Textbox")

---@class ui.modals.locations.LocationEditor : ui.ModalView
---@operator call: ui.modals.locations.LocationEditor
---@field location rizu.api.Location?
local LocationEditor = ModalView + {}

local WIDTH = 820
local HEIGHT = 600
local FIELD_WIDTH = 700

local function trim(value)
	return value:match("^%s*(.-)%s*$")
end

---@param path string
---@return string
local function normalizePath(path)
	return (path:gsub("\\", "/"):gsub("/+$", ""))
end

---@param ui ui.UserInterface
---@param on_saved fun()
function LocationEditor:new(ui, on_saved)
	ModalView.new(self)
	self.ui = ui
	self.on_saved = on_saved
	self.file_picker = FilePicker()
	self.location = nil
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
	self.title = self:add(Label({font_name = "bold", font_size = 36, text = ui.localization:get("locations.add")}))
	self.title:setPosition(48, 38)
	self.subtitle = self:add(Label({
		font_name = "regular", font_size = 18,
		text = ui.localization:get("locations.choose_folder_hint"), color = Colors.muted,
	}))
	self.subtitle:setPosition(48, 88)

	self.name_input = self:add(Textbox({label = ui.localization:get("locations.name"), width = FIELD_WIDTH, placeholder = ui.localization:get("locations.name_placeholder")}))
	self.name_input:setPosition(48, 140)
	self.path_input = self:add(Textbox({label = ui.localization:get("locations.path"), width = 490, placeholder = ui.localization:get("locations.path_placeholder")}))
	self.path_input:setPosition(48, 225)
	self.choose_button = self:add(Button(ui.localization:get("locations.choose_folder"), function() self:chooseFolder() end, {
		variant = "primary", shape = "capsule", font_name = "medium", font_size = 16,
	}))
	self.choose_button:setSize(190, 40):setPosition(558, 250)

	self.info = self:add(Label({font_name = "regular", font_size = 18, text = "", color = Colors.muted}))
	self.info:setPosition(48, 380):setSize(FIELD_WIDTH, 72)
	self.status = self:add(Label({font_name = "regular", font_size = 16, text = "", color = Colors.danger}))
	self.status:setPosition(48, 465):setSize(FIELD_WIDTH, 42)

	self.save_button = self:add(Button(ui.localization:get("locations.add"), function() self:save() end, {
		variant = "primary", shape = "capsule", font_name = "medium", font_size = 18,
	}))
	self.save_button:setSize(190, 46):setPosition(310, 525)
	self.cancel_button = self:add(Button(ui.localization:get("locations.cancel"), function() ui.modal_manager:hideModal(self) end, {
		variant = "secondary", shape = "capsule", font_name = "regular", font_size = 18,
	}))
	self.cancel_button:setSize(150, 46):setPosition(520, 525)
end

---@param location rizu.api.Location?
function LocationEditor:open(location)
	self.location = location
	self.status:setText("")
	if location then
		self.title:setText(self.ui.localization:get("locations.edit"))
		self.subtitle:setText(self.ui.localization:get("locations.edit_hint"))
		self.name_input:setText(location.name or "")
		local library = self.ui.api.library
		self.path_input:setText(library:getLocationPath(location) or "")
		self.save_button.text = self.ui.localization:get("locations.save_changes")
		self.save_button:setVariant("success")
		local info = library:getLocationInfo(location)
		self.info:setText(("Status: %s\nChart sets: %d   Chart files: %d   Hashed: %d"):format(
			info.status, info.chart_sets, info.charts, info.hashed_charts
		))
	else
		self.title:setText(self.ui.localization:get("locations.add"))
		self.subtitle:setText(self.ui.localization:get("locations.choose_folder_hint"))
		self.name_input:setText("")
		self.path_input:setText("")
		self.save_button.text = self.ui.localization:get("locations.add")
		self.save_button:setVariant("primary")
		self.info:setText(self.ui.localization:get("locations.mount_hint"))
	end
	self.ui.modal_manager:showModal(self)
end

function LocationEditor:chooseFolder()
	self.file_picker:openFolder(self.ui.localization:get("locations.select_chart_folder"), function(path, err)
		if path then
			self.path_input:setText(path)
		elseif err then
			self.status:setText(err)
		end
	end)
end

function LocationEditor:save()
	local name = trim(self.name_input:getText())
	local path = trim(self.path_input:getText())
	if name == "" or path == "" then
		self.status:setText(self.ui.localization:get("locations.name_path_required"))
		return
	end

	local library = self.ui.api.library
	local normalized = normalizePath(path)
	for _, other in ipairs(library:getLocations()) do
		local is_self = self.location and other.id == self.location.id
		if not is_self and normalizePath(library:getLocationPath(other)) == normalized then
			self.status:setText(self.ui.localization:get("locations.already_added", {name = other.name}))
			return
		end
	end
	local ok, err
	if self.location then
		ok, err = library:updateLocation(self.location, name, path)
	else
		ok, err = library:addLocation(name, path)
	end
	if not ok then
		self.status:setText(self.ui.localization:get("locations.save_error", {error = err}))
		return
	end

	self.ui.modal_manager:hideModal(self)
	self.on_saved()
end

function LocationEditor:show()
	self:setVisible(true)
	self:fadeIn(0.25, "OutCubic")
end

function LocationEditor:hide()
	self:transformTo("opacity", 0, 0.18, "InCubic", function()
		self:setVisible(false)
	end)
end

function LocationEditor:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return LocationEditor
