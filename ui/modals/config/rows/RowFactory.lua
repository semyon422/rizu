local ControlFactory = require("ui.modals.config.ControlFactory")
local KeybindRow = require("ui.modals.config.rows.KeybindRow")
local SegmentedRow = require("ui.modals.config.rows.SegmentedRow")
local SelectRow = require("ui.modals.config.rows.SelectRow")
local SliderRow = require("ui.modals.config.rows.SliderRow")
local Textbox = require("ui.views.form.Textbox")
local ToggleRow = require("ui.modals.config.rows.ToggleRow")

---Binds settings to the settings modal's rows.
return ControlFactory.create({
	boolean = ToggleRow,
	number = SliderRow,
	choice = SelectRow,
	segmented_choice = SegmentedRow,
	string = Textbox, -- shortcut: a plain textbox without the row look, give it one when a section binds a string setting.
	key_bindings = KeybindRow,
})
