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

return test
