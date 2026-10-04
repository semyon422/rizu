local decibel = require("decibel")
local ActionMap = require("gui.input.ActionMap")
local Inputs = require("gui.input.Inputs")
local FakeFilesystem = require("fs.FakeFilesystem")
local Overlay = require("ui.Overlay")
local Settings = require("rizu.config.Settings")
local UiActions = require("ui.UiActions")

local test = {}

---@param action string
---@return gui.Inputs
local function createInputs(action)
	local actions = ActionMap()
	actions:defineAction(action, {{key = "test_action"}})
	local inputs = Inputs()
	inputs:setActionMap(actions)
	inputs:receive({name = "keypressed", "test_action"}, {
		control = false, shift = false, alt = false, super = false,
	})
	return inputs
end

---@param settings rizu.config.Config
---@param action string
local function handleVolumeAction(settings, action)
	local overlay = setmetatable({
		ui = {
			game = {settings = settings},
			gameplay = {},
			screen_manager = {input_screen = {}},
		},
	}, {__index = Overlay})
	overlay:onHandleInputs(createInputs(action))
end

---@param t testing.T
function test.master_volume_scroll_uses_linear_step(t)
	local settings = Settings.createConfig(FakeFilesystem())
	local keys = Settings.keys.audio
	settings:setNumber(keys.volume_master, 0.5)

	handleVolumeAction(settings, UiActions.master_volume_increase)
	t:aeq(settings:getNumber(keys.volume_master), 0.55, 0.000001)
end

---@param t testing.T
function test.master_volume_scroll_uses_decibel_step_for_logarithmic_volume(t)
	local settings = Settings.createConfig(FakeFilesystem())
	local keys = Settings.keys.audio
	settings:setChoice(keys.volume_type, "logarithmic")
	settings:setNumber(keys.volume_master, decibel.lf_to_f(-20))

	handleVolumeAction(settings, UiActions.master_volume_decrease)
	t:aeq(settings:getNumber(keys.volume_master), decibel.lf_to_f(-21), 0.000001)

	handleVolumeAction(settings, UiActions.master_volume_increase)
	t:aeq(settings:getNumber(keys.volume_master), decibel.lf_to_f(-20), 0.000001)
end

---@param t testing.T
function test.command_palette_is_not_opened_during_gameplay(t)
	local gameplay = {}
	local palette_opened = false
	local overlay = {
		ui = {
			game = {settings = Settings.createConfig(FakeFilesystem())},
			gameplay = gameplay,
			screen_manager = {input_screen = gameplay},
		},
		modal_manager = {
			attachPalette = function()
				palette_opened = true
			end,
		},
	}
	setmetatable(overlay, {__index = Overlay})

	overlay:onHandleInputs(createInputs(UiActions.command_palette))

	t:eq(palette_opened, false)
end

return test
