local decibel = require("decibel")
local FakeFilesystem = require("fs.FakeFilesystem")
local Overlay = require("ui.Overlay")
local Settings = require("rizu.config.Settings")
local UiActions = require("ui.UiActions")

local test = {}

---@param action string
---@return gui.Inputs
local function createInputs(action)
	return {
		consumeActionJustPressed = function(_, requested_action)
			return requested_action == action
		end,
	} --[[@as gui.Inputs]]
end

---@param settings rizu.config.Config
---@param action string
local function handleVolumeAction(settings, action)
	Overlay.onHandleInputs({
		ui = {game = {settings = settings}},
	}, createInputs(action))
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
