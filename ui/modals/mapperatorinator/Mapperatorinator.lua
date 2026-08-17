local Colors = require("ui.Colors")
local Dropdown = require("ui.views.form.Dropdown")
local FlowContainer = require("gui.layout.FlowContainer")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local Slider = require("ui.views.form.Slider")
local Textbox = require("ui.views.form.Textbox")
local Button = require("ui.views.Button")

---@class ui.modals.mapperatorinator.Mapperatorinator : ui.ModalView
---@operator call: ui.modals.mapperatorinator.Mapperatorinator
local Mapperatorinator = ModalView + {}

local WIDTH = 850
local HEIGHT = 790
local FORM_WIDTH = 700

---@param workflow rizu.mapperatorinator.Workflow
---@param config rizu.config.Config
---@param on_close fun()
function Mapperatorinator:new(workflow, config, on_close)
	ModalView.new(self)
	self.workflow = workflow
	self.config = config
	self.on_close = on_close
	self.audio_path = ""

	self:setSize(WIDTH, HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setScale(0.9, 0.9)
	self:setOpacity(0)
	self:setVisible(false)
	self:setClip(true)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt, sprites.nineslice_modal_t, sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l, sprites.nineslice_modal_c, sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb, sprites.nineslice_modal_b, sprites.nineslice_modal_rb,
	})

	local title = self:add(Label({font_name = "bold", font_size = 32, text = "Mapperatorinator"}))
	title:setOffset(75, 28)
	local subtitle = self:add(Label({
		font_name = "regular", font_size = 18,
		text = "Prototype AI beatmap generation — review AI output before publishing.",
		color = Colors.text_muted,
	}))
	subtitle:setOffset(75, 72)

	self.form = Form({direction = "column", gap = 18, padding = {0, 8, 0, 20}})
	self.scroll_view = self:add(ScrollView(self.form))
	self.scroll_view:anchorFixed(75, 112, FORM_WIDTH, 530)
	self.form_selection = self.scroll_view:add(FormSelection(self.form))

	local keys = {
		repository_path = "mapperatorinator.repository_path",
		python_path = "mapperatorinator.python_path",
		gamemode = "mapperatorinator.gamemode",
		difficulty = "mapperatorinator.difficulty",
		keycount = "mapperatorinator.keycount",
		year = "mapperatorinator.year",
	}
	self.audio_label = self.form:add(Label({font_name = "medium", font_size = 18, text = "Audio: not selected"}))
	self.form:add(Textbox({
		label = "Mapperatorinator repository",
		text = config:getString(keys.repository_path), width = FORM_WIDTH,
		on_change = function(value) config:setString(keys.repository_path, value) end,
	}))
	self.form:add(Textbox({
		label = "Python executable",
		text = config:getString(keys.python_path), width = FORM_WIDTH,
		on_change = function(value) config:setString(keys.python_path, value) end,
	}))
	self.form:add(Dropdown({
		label = "Game mode", options = config:getChoices(keys.gamemode),
		value = config:getChoice(keys.gamemode), width = FORM_WIDTH,
		on_change = function(value) config:setChoice(keys.gamemode, value) end,
	}))
	self.form:add(Slider({
		label = "Target difficulty", value = config:getNumber(keys.difficulty),
		min = 0.1, max = 15, step = 0.1, width = FORM_WIDTH,
		value_format = function(value) return ("%.1f★"):format(value) end,
		on_change = function(value) config:setNumber(keys.difficulty, value) end,
	}))
	self.form:add(Slider({
		label = "Mania key count", value = config:getNumber(keys.keycount),
		min = 1, max = 18, step = 1, width = FORM_WIDTH,
		value_format = function(value) return ("%dK"):format(value) end,
		on_change = function(value) config:setNumber(keys.keycount, value) end,
	}))
	self.form:add(Slider({
		label = "Style year", value = config:getNumber(keys.year),
		min = 2007, max = 2024, step = 1, width = FORM_WIDTH,
		value_format = function(value) return ("%d"):format(value) end,
		on_change = function(value) config:setNumber(keys.year, value) end,
	}))
	self.form:fitContent()

	self.status_label = self:add(Label({
		font_name = "regular", font_size = 18, text = workflow.status,
		color = Colors.text_muted, align = "center",
	}))
	self.status_label:anchorFixed(75, 660, FORM_WIDTH, 44)

	self.generate_button = self:add(Button("Generate", function() self:generate() end))
	self.generate_button:setSize(260, 60)
	self.generate_button:setOffset(175, 718)
	self.close_button = self:add(Button("Close", on_close))
	self.close_button:setSize(180, 60)
	self.close_button:setOffset(495, 718)
end

---@param path string
function Mapperatorinator:setAudioPath(path)
	self.audio_path = path
	self.audio_label:setText("Audio: " .. path)
	self.workflow.status = "Configure the prototype options, then generate."
end

function Mapperatorinator:generate()
	local ok, err = self.workflow:start(self.audio_path, self.config)
	if not ok then
		self.workflow.status = assert(err)
	else
		self.config:save()
	end
end

---@param dt number
function Mapperatorinator:update(dt)
	self.status_label:setText(self.workflow.status)
	self.generate_button.text = self.workflow:isBusy() and "Working…" or "Generate"
end

function Mapperatorinator:show()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function Mapperatorinator:hide()
	self.form:closeActiveDropdown()
	self.config:save()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function Mapperatorinator:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return Mapperatorinator
