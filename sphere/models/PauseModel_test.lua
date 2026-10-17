local PauseModel = require("sphere.models.PauseModel")
local Settings = require("rizu.config.Settings")
local FakeFilesystem = require("fs.FakeFilesystem")
local flux = require("flux")

local test = {}

---@param t testing.T
function test.transition_times_follow_settings(t)
	local settings = Settings.createConfig(FakeFilesystem())
	local model = PauseModel(settings, {})
	local keys = Settings.keys.gameplay
	for state, key in pairs({
		["play-pause"] = keys.time_play_pause,
		["pause-play"] = keys.time_pause_play,
		["play-retry"] = keys.time_play_retry,
		["pause-retry"] = keys.time_pause_retry,
	}) do
		settings:setNumber(key, 1.2)
		t:eq(model:getProgressTime(state), 1.2)
	end
	t:eq(model:getProgressTime("play"), nil)
end

---@param t testing.T
function test.load_stops_previous_transition(t)
	local model = PauseModel(Settings.createConfig(FakeFilesystem()), {})
	model:load()
	model:changePlayState("retry")
	flux.update(0.2)
	model:load()
	flux.update(1)
	model:update()
	t:eq(model.state, "play")
	t:eq(model.progress, 0)
	t:eq(model.needRetry, false)
end

return test
