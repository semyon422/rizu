local Gameplay = require("ui.screens.gameplay.Gameplay")
local UiActions = require("ui.UiActions")
local PauseModel = require("sphere.models.PauseModel")
local Settings = require("rizu.config.Settings")
local FakeFilesystem = require("fs.FakeFilesystem")
local flux = require("flux")

local test = {}

---@param state string
---@return ui.screens.gameplay.Gameplay
---@return sphere.PauseModel
local function create(state)
	local settings = Settings.createConfig(FakeFilesystem())
	settings:setNumber(Settings.keys.gameplay.time_play_pause, 0.5)
	local model = PauseModel(settings, {})
	model:load()
	model.state = state
	local screen = setmetatable({
		game = {pauseModel = model},
		gameplay_interactor = {changePlayState = function(_, target)
			model:changePlayState(target)
		end},
	}, {__index = Gameplay})
	---@cast screen ui.screens.gameplay.Gameplay
	return screen, model
end

---@param screen ui.screens.gameplay.Gameplay
---@param pressed string?
---@param released string?
local function input(screen, pressed, released)
	screen:onHandleInputs({
		consumeActionJustPressed = function(_, action) return action == pressed end,
		consumeActionJustReleased = function(_, action) return action == released end,
	})
end

---@param t testing.T
function test.retry_requires_hold_from_play_and_pause(t)
	for _, state in ipairs({"play", "pause"}) do
		local screen, model = create(state)
		input(screen, UiActions.gameplay_retry)
		flux.update(0.2)
		model:update()
		t:eq(model.needRetry, false)
		input(screen, nil, UiActions.gameplay_retry)
		flux.update(1)
		model:update()
		t:eq(model.state, state)
		t:eq(model.progress, 0)
		t:eq(model.needRetry, false)

		input(screen, UiActions.gameplay_retry)
		flux.update(0.5)
		model:update()
		t:eq(model.needRetry, true)
		model:load()
		input(screen, nil, UiActions.gameplay_retry)
		flux.update(1)
		model:update()
		t:eq(model.needRetry, false)
	end
end

---@param t testing.T
function test.pause_release_cancels_hold(t)
	local screen, model = create("play")
	input(screen, UiActions.gameplay_pause)
	flux.update(0.2)
	t:eq(model.state, "play-pause")
	input(screen, nil, UiActions.gameplay_pause)
	flux.update(1)
	model:update()
	t:eq(model.state, "play")
	t:eq(model.progress, 0)
end

---@param t testing.T
function test.resume_release_keeps_countdown_and_second_press_cancels(t)
	local screen, model = create("pause")
	input(screen, UiActions.gameplay_pause)
	flux.update(0.2)
	input(screen, nil, UiActions.gameplay_pause)
	t:eq(model.state, "pause-play")
	t:assert(model.progress > 0)
	input(screen, UiActions.gameplay_pause)
	flux.update(1)
	model:update()
	t:eq(model.state, "pause")
	t:eq(model.progress, 0)
end

---@param t testing.T
function test.press_and_release_in_same_frame_cancels_retry(t)
	local screen, model = create("play")
	input(screen, UiActions.gameplay_retry, UiActions.gameplay_retry)
	flux.update(1)
	model:update()
	t:eq(model.state, "play")
	t:eq(model.needRetry, false)
end

---@param t testing.T
function test.completed_pause_and_resume(t)
	local screen, model = create("play")
	local pauses, resumes = 0, 0
	function model:pause()
		pauses = pauses + 1
		self.state = "pause"
	end
	function model:play()
		resumes = resumes + 1
		self.state = "play"
	end
	input(screen, UiActions.gameplay_pause)
	flux.update(0.5)
	model:update()
	t:eq(pauses, 1)
	input(screen, nil, UiActions.gameplay_pause)
	t:eq(model.state, "pause")
	input(screen, UiActions.gameplay_pause)
	input(screen, nil, UiActions.gameplay_pause)
	flux.update(0.5)
	model:update()
	t:eq(resumes, 1)
	t:eq(model.state, "play")
end

---@param t testing.T
function test.aim_completion_saves_diagnostic_replay_without_score_screen(t)
	local saved, paused = 0, 0
	local text, visible
	local screen = setmetatable({
		is_aim = true, is_playing = true, sequence_canvas = {},
		game = {rhythm_engine = {getProgress = function() return 1 end, aim_rules = {hits = 2, misses = 1}}},
		gameplay_interactor = {
			saveAimReplay = function() saved = saved + 1 end,
			pause = function() paused = paused + 1 end,
		},
		aim_summary = {setText = function(_, value) text = value end, setVisible = function(_, value) visible = value end},
	}, {__index = Gameplay})
	screen:observeCompletion()
	t:eq(saved, 1)
	t:eq(paused, 1)
	t:eq(screen.gameplay_interactor.aim_complete, true)
	t:eq(screen.is_playing, false)
	t:eq(visible, true)
	t:assert(text:find("Hit 2 / Miss 1", 1, true))
end

---@param t testing.T
function test.taiko_completion_uses_local_summary(t)
	local saved, paused = 0, 0
	local screen = setmetatable({
		is_aim = true, is_taiko = true, is_playing = true, sequence_canvas = {},
		game = {rhythm_engine = {getProgress = function() return 1 end, taiko_rules = {hits = 3, misses = 1}}},
		gameplay_interactor = {
			saveAimReplay = function() saved = saved + 1 end,
			pause = function() paused = paused + 1 end,
		},
		aim_summary = {setText = function(_, text) t:assert(text:find("Hit 3 / Miss 1", 1, true)) end, setVisible = function() end},
	}, {__index = Gameplay})
	screen:observeCompletion()
	t:eq(saved, 1)
	t:eq(paused, 1)
	t:eq(screen.gameplay_interactor.aim_complete, true)
end

return test
