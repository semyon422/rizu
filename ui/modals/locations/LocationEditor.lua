local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local FilePicker = require("rizu.files.FilePicker")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local path_util = require("path_util")
local Resources = require("ui.Resources")
local Textbox = require("ui.views.form.Textbox")

---@class ui.modals.locations.LocationEditor : ui.ModalView
---@operator call: ui.modals.locations.LocationEditor
---@field location rizu.library.Location?
local LocationEditor = ModalView + {}

local WIDTH = 820
local HEIGHT = 600
local FIELD_WIDTH = 700

local function trim(value)
	return value:match("^%s*(.-)%s*$")
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
	self.title = self:add(Label({font_name = "bold", font_size = 36, text = "Add location"}))
	self.title:setPosition(48, 38)
	self.subtitle = self:add(Label({
		font_name = "regular", font_size = 18,
		text = "Choose a folder containing Charts.", color = Colors.muted,
	}))
	self.subtitle:setPosition(48, 88)

	self.name_input = self:add(Textbox({label = "Name", width = FIELD_WIDTH, placeholder = "My Charts"}))
	self.name_input:setPosition(48, 140)
	self.path_input = self:add(Textbox({label = "Path", width = 490, placeholder = "/path/to/charts"}))
	self.path_input:setPosition(48, 225)
	self.choose_button = self:add(Button("Choose folder", function() self:chooseFolder() end, {
		variant = "primary", shape = "capsule", font_name = "medium", font_size = 16,
	}))
	self.choose_button:setSize(190, 40):setPosition(558, 250)

	self.info = self:add(Label({font_name = "regular", font_size = 18, text = "", color = Colors.muted}))
	self.info:setPosition(48, 380):setSize(FIELD_WIDTH, 72)
	self.status = self:add(Label({font_name = "regular", font_size = 16, text = "", color = Colors.danger}))
	self.status:setPosition(48, 465):setSize(FIELD_WIDTH, 42)

	self.save_button = self:add(Button("Add location", function() self:save() end, {
		variant = "primary", shape = "capsule", font_name = "medium", font_size = 18,
	}))
	self.save_button:setSize(190, 46):setPosition(310, 525)
	self.cancel_button = self:add(Button("Cancel", function() ui.modal_manager:hideModal(self) end, {
		variant = "secondary", shape = "capsule", font_name = "regular", font_size = 18,
	}))
	self.cancel_button:setSize(150, 46):setPosition(520, 525)
end

---@param location rizu.library.Location?
function LocationEditor:open(location)
	self.location = location
	self.status:setText("")
	if location then
		self.title:setText("Edit location")
		self.subtitle:setText("Change its display name or select a different folder.")
		self.name_input:setText(location.name)
		local display_path = location.is_relative
			and path_util.join(self.ui.game.library.locations.root, location.path)
			or location.path
		self.path_input:setText(display_path)
		self.save_button.text = "Save changes"
		self.save_button:setVariant("success")
		local locations = self.ui.game.library.locations
		local info = locations.info[location.id] or {}
		self.info:setText(("Status: %s\nChart sets: %d   Chart files: %d   Hashed: %d"):format(
			locations.status[location.id] or "unknown",
			info.chartfile_sets or 0,
			info.chartfiles or 0,
			info.hashed_chartfiles or 0
		))
	else
		self.title:setText("Add location")
		self.subtitle:setText("Choose a folder containing Charts.")
		self.name_input:setText("")
		self.path_input:setText("")
		self.save_button.text = "Add location"
		self.save_button:setVariant("primary")
		self.info:setText("The folder will be mounted and added to your local library.")
	end
	self.ui.modal_manager:showModal(self)
end

function LocationEditor:chooseFolder()
	self.file_picker:openFolder("Select Chart folder", function(path, err)
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
		self.status:setText("Name and path are required.")
		return
	end

	local game = self.ui.game
	local library_locations = game.library.locations
	local repo = game.library.locationsRepo
	local created_location ---@type rizu.library.Location?
	local previous_location ---@type rizu.library.Location?
	local ok, err = pcall(function()
		if self.location then
			local location = assert(repo:selectLocationById(self.location.id), "Location no longer exists")
			previous_location = {
				id = location.id,
				name = location.name,
				path = location.path,
				is_relative = location.is_relative,
				is_internal = location.is_internal,
			}
			library_locations:updateLocationPath(location, path)
			location.name = name
			repo:updateLocation(location)
		else
			created_location = repo:insertLocation({
				name = name, path = path, is_relative = false, is_internal = false,
			})
			library_locations:updateLocationPath(created_location, path)
		end
	end)
	if not ok then
		if created_location then
			library_locations:deleteLocation(created_location.id)
		elseif previous_location then
			pcall(function()
				repo:updateLocation(previous_location)
				library_locations:mountLocation(previous_location)
			end)
		end
		self.status:setText("Could not save location: " .. tostring(err))
		return
	end

	library_locations:selectLocations()
	game.chartSelector:noDebounceRefresh()
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
