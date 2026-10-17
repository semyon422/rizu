local EditorScrollInputService = require("rizu.editor.view.EditorScrollInputService")
local EditorViewState = require("rizu.editor.state.EditorViewState")

local test = {}

local function createContext(flags, calls)
	local viewState = EditorViewState()
	local timer = {
		is_playing = false,
	}

	return {
		viewState = viewState,
		timer = timer,
		isFineScrollRequested = function()
			return flags.fine == true
		end,
		isSnapChangeRequested = function()
			return flags.snap == true
		end,
		isSpeedChangeRequested = function()
			return flags.speed == true
		end,
		scrollSecondsDelta = function(_, delta)
			table.insert(calls, "seconds:" .. delta)
		end,
		scrollSnaps = function(_, scroll)
			table.insert(calls, "snaps:" .. scroll)
		end,
		isPlaying = function()
			return timer.is_playing
		end,
		pause = function()
			table.insert(calls, "pause")
			timer.is_playing = false
		end,
		play = function()
			table.insert(calls, "play")
			timer.is_playing = true
		end,
		isDragging = function(_, owner)
			return viewState:isDragging(owner)
		end,
		setDragging = function(_, dragging, owner)
			viewState:setDragging(dragging, owner)
		end,
		incSnap = function()
			table.insert(calls, "inc")
		end,
		decSnap = function()
			table.insert(calls, "dec")
		end,
		getLogSpeed = function()
			table.insert(calls, "get-speed")
			return 10
		end,
		setLogSpeed = function(_, speed)
			table.insert(calls, "set-speed:" .. speed)
		end,
	}
end

local noteSkin = {
	unit = 50,
	getInverseTimePosition = function(_, y)
		return y / 10
	end,
}

---@param t testing.T
function test.fine_scroll_overrides_and_restores_speed(t)
	local calls = {}
	local flags = {
		fine = true,
	}
	local editor = {
		speed = 2,
	}
	local context = createContext(flags, calls)
	local service = EditorScrollInputService()

	local state = service:update(context, noteSkin, editor, {
		mouseY = 20,
		dragActive = false,
	})

	t:eq(editor.speed, 200)
	t:eq(state.showMouseDelta, true)

	flags.fine = false
	service:update(context, noteSkin, editor, {
		mouseY = 20,
		dragActive = false,
	})

	t:eq(editor.speed, 2)
end

---@param t testing.T
function test.drag_scroll_pauses_and_resumes_playback(t)
	local calls = {}
	local flags = {
		fine = true,
	}
	local editor = {
		speed = 2,
	}
	local context = createContext(flags, calls)
	context.timer.is_playing = true
	local service = EditorScrollInputService()
	service.prevMouseY = 10

	service:update(context, noteSkin, editor, {
		mouseY = 30,
		dragActive = true,
	})

	t:eq(context.viewState:isDragging(), true)
	t:eq(context.viewState:isDragging("scroll"), true)
	t:tdeq(calls, {"seconds:0.01", "pause"})

	flags.fine = false
	service:update(context, noteSkin, editor, {
		mouseY = 30,
		dragActive = false,
	})

	t:eq(context.viewState:isDragging(), false)
	t:tdeq(calls, {"seconds:0.01", "pause", "play"})
end

---@param t testing.T
function test.inactive_scroll_does_not_resume_chart_slider_drag(t)
	local calls = {}
	local editor = {
		speed = 2,
	}
	local context = createContext({}, calls)
	context.viewState:setDragging(true, "chartSlider")

	EditorScrollInputService():update(context, noteSkin, editor, {
		mouseY = 30,
		dragActive = false,
	})

	t:eq(context.viewState:isDragging("chartSlider"), true)
	t:tdeq(calls, {})
end

---@param t testing.T
function test.scroll_changes_snap_or_speed(t)
	local calls = {}
	local editor = {
		speed = 1,
	}

	EditorScrollInputService():update(createContext({snap = true}, calls), noteSkin, editor, {
		mouseY = 0,
		dragActive = false,
		scroll = 1,
	})
	EditorScrollInputService():update(createContext({snap = true}, calls), noteSkin, editor, {
		mouseY = 0,
		dragActive = false,
		scroll = -1,
	})
	EditorScrollInputService():update(createContext({speed = true}, calls), noteSkin, editor, {
		mouseY = 0,
		dragActive = false,
		scroll = 2,
	})

	t:tdeq(calls, {"inc", "dec", "get-speed", "set-speed:12"})
end

---@param t testing.T
function test.normal_scroll_preserves_current_double_scroll_semantics(t)
	local calls = {}
	local editor = {
		speed = 1,
	}
	local context = createContext({}, calls)
	context.timer.is_playing = true

	EditorScrollInputService():update(context, noteSkin, editor, {
		mouseY = 0,
		dragActive = false,
		scroll = -1,
	})

	t:tdeq(calls, {"snaps:-1", "snaps:-1"})
end

return test
