local MusicSpeedControl = require("ui.screens.song_select.MusicSpeedControl")
local TimeRateModel = require("sphere.models.TimeRateModel")
local ReplayBase = require("sea.replays.ReplayBase")

local test = {}

---@return ui.screens.song_select.MusicSpeedControl
---@return fun(): integer
local function newControl()
	local changes = 0
	local view = setmetatable({
		time_rate_model = TimeRateModel(ReplayBase()),
		modifier_select_model = {
			change = function() changes = changes + 1 end,
		},
	}, {__index = MusicSpeedControl})
	return view --[[@as ui.screens.song_select.MusicSpeedControl]], function() return changes end
end

---@param t testing.T
function test.formats_both_modes(t)
	local view = newControl()
	view:setRate(1.25)
	t:eq(view:getText(), "1.25x")
	view.time_rate_model.replayBase.rate_type = "exp"
	for _, value in ipairs({-20, -1, 0, 1, 20}) do
		view:setRate(value)
		t:eq(view:getText(), value > 0 and "+" .. value or tostring(value))
	end
end

---@param t testing.T
function test.click_preserves_speed_and_notifies(t)
	local view, changes = newControl()
	view:setRate(1.25)
	local rate = view.time_rate_model.replayBase.rate
	for _, mode in ipairs({"exp", "linear"}) do
		t:eq(view:onMouseClick({button = 1} --[[@as gui.MouseClickEvent]]), true)
		t:eq(view.time_rate_model.replayBase.rate_type, mode)
		t:eq(view.time_rate_model.replayBase.rate, rate)
	end
	view:onMouseClick({button = 2} --[[@as gui.MouseClickEvent]])
	t:eq(view.time_rate_model.replayBase.rate_type, "linear")
	t:eq(changes(), 3)
end

---@param t testing.T
function test.scroll_uses_mode_steps(t)
	local view, changes = newControl()
	view:onScroll({direction_y = 1} --[[@as gui.ScrollEvent]])
	t:eq(view:getText(), "1.05x")
	view.time_rate_model.replayBase.rate_type = "exp"
	view:setRate(0)
	view:onScroll({direction_y = 1} --[[@as gui.ScrollEvent]])
	t:eq(view:getText(), "+1")
	view:onScroll({direction_y = -2} --[[@as gui.ScrollEvent]])
	t:eq(view:getText(), "-1")
	view:onScroll({direction_y = 0} --[[@as gui.ScrollEvent]])
	t:eq(view:getText(), "-1")
	t:eq(changes(), 5)
end

---@param t testing.T
function test.drag_uses_mode_range_and_clamps(t)
	local view = newControl()
	view.time_rate_model.replayBase.rate_type = "exp"
	view:onDragStart({button = 1, press_x = 100, x = 104} --[[@as gui.DragStartEvent]])
	view:onDrag({button = 1, x = 109} --[[@as gui.DragEvent]])
	t:eq(view:getText(), "+1")
	view:onDrag({button = 1, x = 1000} --[[@as gui.DragEvent]])
	t:eq(view:getText(), "+20")
	view:onDrag({button = 1, x = -1000} --[[@as gui.DragEvent]])
	t:eq(view:getText(), "-20")
	view.time_rate_model.replayBase.rate_type = "linear"
	view:setRate(1)
	view:onDragStart({button = 1, press_x = 100, x = 104} --[[@as gui.DragStartEvent]])
	view:onDrag({button = 1, x = 124} --[[@as gui.DragEvent]])
	t:eq(view:getText(), "1.25x")
end

return test
