local ButtonRow = require("ui.views.form.ButtonRow")
local Colors = require("ui.Colors")
local Form = require("ui.views.form.Form")
local FormControl = require("ui.views.form.FormControl")
local FormNavigation = require("ui.views.form.FormNavigation")
local FormSelection = require("ui.views.form.FormSelection")
local Label = require("ui.views.Label")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local SegmentedControl = require("ui.views.form.SegmentedControl")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")
local TimingValueControl = require("ui.views.form.TimingValueControl")

---@class ui.modals.score_systems.ScoreSystems.Row
---@field name string
---@field on_remove fun()? nil for a row that cannot be removed.

---The stored score systems, one row each, with a Remove cell. Up and down move between the rows,
---Enter or Delete removes the selected one.
---@class ui.modals.score_systems.ScoreSystems.Table : ui.views.form.FormControl
---@operator call: ui.modals.score_systems.ScoreSystems.Table
---@field rows ui.modals.score_systems.ScoreSystems.Row[]
---@field header string
---@field remove_text string
---@field remove_width number
---@field cursor integer
---@field font love.Font
---@field header_font love.Font
local Table = FormControl + {}

local ROW_HEIGHT = 40
local CELL_PADDING = 16
local CORNER_RADIUS = 6

---@param rows ui.modals.score_systems.ScoreSystems.Row[]
---@param header string
---@param remove_text string
---@param width number
function Table:new(rows, header, remove_text, width)
	FormControl.new(self)
	self.rows = rows
	self.header = header
	self.remove_text = remove_text
	self.cursor = 1
	self.font = Resources.getFont("medium", 16)
	self.header_font = Resources.getFont("bold", 14)
	self.remove_width = self.font:getWidth(remove_text) + CELL_PADDING * 2
	self:setSize(width, ROW_HEIGHT * (#rows + 1))
	self.handles_mouse_input = true
end

---@param screen_x number
---@param screen_y number
---@return integer? index
---@return boolean in_remove_cell
function Table:getRowAt(screen_x, screen_y)
	local x, y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	local index = math.floor(y / ROW_HEIGHT) -- 0 is the header
	if index < 1 or index > #self.rows then
		return nil, false
	end
	return index, x >= self.width - self.remove_width
end

---@param index integer
---@return boolean removed
function Table:remove(index)
	local row = self.rows[index]
	if not row or not row.on_remove then
		return false
	end
	row.on_remove()
	return true
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function Table:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	local index, in_remove_cell = self:getRowAt(e.x, e.y)
	if index and in_remove_cell then
		self.cursor = index
		return self:remove(index)
	end
end

---@param e gui.KeyDownEvent?
---@return boolean activated
function Table:activate(e)
	return self:remove(self.cursor)
end

---@param e gui.KeyDownEvent
---@return boolean handled
function Table:onFormKeyDown(e)
	if e.key == "delete" then
		return self:remove(self.cursor)
	end
	local direction = e.key == "down" and 1 or e.key == "up" and -1 or nil
	local cursor = direction and self.cursor + direction
	-- At the first and the last row the form moves on to the next control.
	if not cursor or cursor < 1 or cursor > #self.rows then
		return false
	end
	self.cursor = cursor
	return true
end

---@return boolean
function Table:isKeyboardSelected()
	local form = self.parent and self.parent.parent
	---@cast form ui.views.form.Form?
	return form ~= nil and form.selected_control == self and form.navigation == FormNavigation.Keyboard
end

function Table:draw()
	local width, height = self.width, self.height
	local hovered, in_remove_cell ---@type integer?, boolean
	local inputs = self.screen and self.screen.inputs
	if self.mouse_over and inputs then
		hovered, in_remove_cell = self:getRowAt(inputs.mouse_x, inputs.mouse_y)
	end
	local cursor = self:isKeyboardSelected() and self.cursor or nil

	Painter.setColorTable(Colors.background)
	love.graphics.rectangle("fill", 0, 0, width, height, CORNER_RADIUS, CORNER_RADIUS)
	for index in ipairs(self.rows) do
		if index == hovered or index == cursor then
			Painter.setColorTable(Colors.surface)
			love.graphics.rectangle("fill", 0, index * ROW_HEIGHT, width, ROW_HEIGHT)
		end
	end

	Painter.setColorTable(Colors.outline)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", 0.5, 0.5, width - 1, height - 1, CORNER_RADIUS, CORNER_RADIUS)
	for index = 1, #self.rows do
		local y = index * ROW_HEIGHT + 0.5
		love.graphics.line(0, y, width, y)
	end

	Painter.snapToPixel()
	love.graphics.setFont(self.header_font)
	Painter.setColorTable(Colors.muted)
	love.graphics.print(self.header, CELL_PADDING, (ROW_HEIGHT - self.header_font:getHeight()) / 2)

	love.graphics.setFont(self.font)
	local text_y = (ROW_HEIGHT - self.font:getHeight()) / 2
	for index, row in ipairs(self.rows) do
		local y = index * ROW_HEIGHT + text_y
		Painter.setColorTable(row.on_remove and Colors.text or Colors.muted)
		love.graphics.print(row.name, CELL_PADDING, y)
		if row.on_remove then
			local active = index == cursor or index == hovered and in_remove_cell
			Painter.setColorTable(active and Colors.danger or Colors.muted)
			love.graphics.printf(self.remove_text, width - self.remove_width, y, self.remove_width, "center")
		end
	end
end

---Adds and removes the score systems whose accuracy is stored with every score.
---@class ui.modals.score_systems.ScoreSystems : ui.ModalView
---@operator call: ui.modals.score_systems.ScoreSystems
---@field scores rizu.api.Scores
---@field library rizu.api.Library
---@field localization ui.localization.Localization
---@field form ui.views.form.Form
---@field scroll_view gui.ScrollView
---@field form_selection ui.views.form.FormSelection
---@field background gui.NineSliceUsage
---@field system string The system to add.
---@field values {[string]: number}
---@field osu_score_version 1|2
---@field private form_invalidated boolean
local ScoreSystems = ModalView + {}

local MODAL_WIDTH = 700
local MODAL_HEIGHT = 720
local FORM_WIDTH = 600
local FORM_X = (MODAL_WIDTH - FORM_WIDTH) / 2
local FORM_Y = 112
local FORM_HEIGHT = MODAL_HEIGHT - FORM_Y - 92

---@param scores rizu.api.Scores
---@param library rizu.api.Library
---@param on_close fun()
---@param localization ui.localization.Localization
function ScoreSystems:new(scores, library, on_close, localization)
	ModalView.new(self)
	self.scores = scores
	self.library = library
	self.localization = localization
	self.system = scores:getAddableAccuracySystems()[1]
	self.values = {}
	self.osu_score_version = 1
	self.form_invalidated = false

	self:setSize(MODAL_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setOpacity(0)
	self:setVisible(false)
	self:setClip(true)
	self.handles_mouse_input = true

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

	self:add(ModalHeader(localization:get("song_select.score_systems_title"),
		localization:get("song_select.score_systems_question")))
	self:add(ModalFooter(on_close, localization:get("settings.close")))

	-- The list spans the modal so the selection marker left of the rows is not clipped.
	self.form = Form({direction = "column", gap = 12, padding = {FORM_X, 8, 0, 0}})
	self.scroll_view = self:add(ScrollView(self.form))
	self.scroll_view:anchorFixed(0, FORM_Y, MODAL_WIDTH, FORM_HEIGHT)
	self.form_selection = self.scroll_view:add(FormSelection(self.form))
	self:rebuildForm()
end

function ScoreSystems:invalidateForm()
	self.form_invalidated = true
end

function ScoreSystems:rebuildForm()
	self.form_invalidated = false
	self.form:closeActiveDropdown()
	self.form:clearSelection()
	self.form:clearRows()

	local scores = self.scores
	local localization = self.localization

	self.form:add(Label({
		font_name = "medium", font_size = 14, color = Colors.danger,
		text = localization:get("song_select.score_systems_warning"),
	}))

	---@type ui.modals.score_systems.ScoreSystems.Row[]
	local rows = {{name = localization:get("song_select.accuracy_system_auto")}}
	for _, token in ipairs(scores:getAccuracySystems()) do
		local scoring = token ~= "auto" and scores:getAccuracySystem(nil, token)
		if scoring then
			table.insert(rows, {name = scoring:getName(), on_remove = function()
				scores:removeAccuracySystem(token)
				self:invalidateForm()
			end})
		end
	end
	self.form:add(Table(rows, localization:get("song_select.score_system"),
		localization:get("song_select.score_systems_remove"), FORM_WIDTH))

	self.form:add(SegmentedControl({
		label = localization:get("song_select.score_systems_new"),
		options = scores:getAddableAccuracySystems(),
		value = self.system,
		format = function(name)
			return TimingSystems.get(name).label
		end,
		on_change = function(name)
			self.system = name
			self:invalidateForm()
		end,
	}))

	local system = TimingSystems.get(self.system)
	if system.score_versions then
		self.form:add(SegmentedControl({
			label = localization:get("song_select.osu_score_version"),
			options = system.score_versions,
			value = self.osu_score_version,
			format = function(version)
				return "V" .. version
			end,
			on_change = function(version)
				self.osu_score_version = version
			end,
		}))
	end
	local value_control = TimingValueControl(system, self.values[self.system] or system.default_value, FORM_WIDTH,
		localization, function(value)
			self.values[self.system] = value
		end)
	if value_control then
		self.form:add(value_control)
	end

	self.form:add(Label({
		font_name = "medium", font_size = 14, color = Colors.muted,
		text = localization:get("song_select.score_systems_recalculate_tip"),
	}))
	self.form:add(ButtonRow({
		buttons = {
			{
				text = localization:get("song_select.score_systems_add"),
				color = Colors.success,
				on_click = function()
					local name = self.system
					if scores:addAccuracySystem(name, self.values[name], self.osu_score_version) then
						self:invalidateForm()
					end
				end,
			},
			{
				text = localization:get("song_select.recalculate_accuracies"),
				on_click = function()
					self.library:recalculateAccuracies()
				end,
			},
		},
	}))

	self.form:fitContent()
end

---@param dt number
function ScoreSystems:update(dt)
	if self.form_invalidated then
		self:rebuildForm()
	end
end

function ScoreSystems:show()
	self:rebuildForm()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function ScoreSystems:hide()
	self.form:closeActiveDropdown()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function ScoreSystems:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return ScoreSystems
