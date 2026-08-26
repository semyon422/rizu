local View = require("gui.View")
local loop = require("rizu.loop.Loop")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local UiActions = require("ui.UiActions")

local GRAPH_WIDTH = 216
local INFO_WIDTH = 240
local WIDTH = GRAPH_WIDTH + INFO_WIDTH
local HEIGHT = 144
local PADDING = 12
local GRAPH_X = PADDING
local GRAPH_Y = 32
local GRAPH_HEIGHT = HEIGHT - GRAPH_Y - PADDING
local FRAME_TIME_CAPACITY = 120
local DEFAULT_GRAPH_MAX_DT = 1 / 30
local MIN_GRAPH_MAX_DT = 0.001
local MAX_GRAPH_MAX_DT = 1
local GRAPH_SCALE_STEP = 1.25
local TIMING_KEYS = {"dt", "event", "update", "draw", "present", "gc", "sleep", "busy"}
local HITCH_MIN_FRAME_TIME = 0.004
local HITCH_BASELINE_MULTIPLIER = 1.75
local HITCH_HIGHLIGHT_DURATION = 0.032
local BASELINE_ALPHA = 0.05

---@class ui.views.FpsView : gui.View
---@operator call: ui.views.FpsView
---@field font love.Font
---@field fps integer
---@field frame_time_baseline number
---@field hitch_highlight_remaining number
---@field frame_times number[]
---@field frame_time_index integer
---@field frame_time_count integer
---@field graph_max_dt number
---@field timing_index integer
---@field private unsubscribe_show_fps function
local FpsView = View + {}

---@param ui_config ui.UiConfig
function FpsView:new(ui_config)
	View.new(self)
	self.font = Resources.getFont("regular", 20)
	self.fps = 0
	self.frame_time_baseline = 0
	self.hitch_highlight_remaining = 0
	---@type number[]
	self.frame_times = {}
	self.frame_time_index = 0
	self.frame_time_count = 0
	self.graph_max_dt = DEFAULT_GRAPH_MAX_DT
	self.timing_index = 1
	self.handles_mouse_input = true
	self:setSize(WIDTH, HEIGHT)
	self:setVisible(ui_config:getBoolean("show_fps"))
	self.unsubscribe_show_fps = ui_config:subscribeBoolean("show_fps", function(value)
		self:setVisible(value)
	end)
end

---@param dt number
function FpsView:update(dt)
	if not self.visible then
		return
	end

	self.fps = dt > 0 and math.floor(1 / dt + 0.5) or 0
	local timing = loop.timings[TIMING_KEYS[self.timing_index]]
	self.frame_time_index = self.frame_time_index % FRAME_TIME_CAPACITY + 1
	self.frame_times[self.frame_time_index] = timing
	self.frame_time_count = math.min(self.frame_time_count + 1, FRAME_TIME_CAPACITY)
	self.hitch_highlight_remaining = math.max(self.hitch_highlight_remaining - dt, 0)

	local baseline = self.frame_time_baseline
	if baseline > 0 and dt > HITCH_MIN_FRAME_TIME and dt > baseline * HITCH_BASELINE_MULTIPLIER then
		self.hitch_highlight_remaining = HITCH_HIGHLIGHT_DURATION
	end
	self.frame_time_baseline = baseline == 0 and dt or baseline * (1 - BASELINE_ALPHA) + dt * BASELINE_ALPHA
end

function FpsView:unload()
	self.unsubscribe_show_fps()
end

---@param e gui.ScrollEvent
---@return boolean handled
function FpsView:onScroll(e)
	if e.direction_y == 0 then
		return false
	end
	local factor = e.direction_y > 0 and 1 / GRAPH_SCALE_STEP or GRAPH_SCALE_STEP
	self.graph_max_dt = math.max(MIN_GRAPH_MAX_DT, math.min(MAX_GRAPH_MAX_DT, self.graph_max_dt * factor))
	return true
end

---@param inputs gui.Inputs
function FpsView:onHandleInputs(inputs)
	if not self.mouse_over then
		return
	end
	local direction
	if inputs:consumeActionJustPressed(UiActions.left) then
		direction = -1
	elseif inputs:consumeActionJustPressed(UiActions.right) then
		direction = 1
	else
		return
	end
	self.timing_index = (self.timing_index + direction - 1) % #TIMING_KEYS + 1
	self.frame_times = {}
	self.frame_time_index = 0
	self.frame_time_count = 0
end

function FpsView:draw()
	local timings = loop.timings
	if self.hitch_highlight_remaining > 0 then
		Painter.setColorRgb(0.8, 0, 0, 0.85)
	else
		Painter.setColorRgb(0, 0, 0, 0.75)
	end
	love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)
	local graph_right = GRAPH_WIDTH - PADDING
	local graph_bottom = GRAPH_Y + GRAPH_HEIGHT
	Painter.setColorTable(Colors.muted)
	love.graphics.setFont(self.font)
	love.graphics.print(("%s  %.1f ms"):format(
		TIMING_KEYS[self.timing_index], self.graph_max_dt * 1000
	), GRAPH_X, PADDING - 2)
	Painter.setColorRgb(1, 1, 1, 0.16)
	love.graphics.rectangle("line", GRAPH_X, GRAPH_Y, graph_right - GRAPH_X, GRAPH_HEIGHT)
	love.graphics.line(GRAPH_X, GRAPH_Y + GRAPH_HEIGHT / 2, graph_right, GRAPH_Y + GRAPH_HEIGHT / 2)

	local count = self.frame_time_count
	if count > 1 then
		local points = {}
		local oldest = count == FRAME_TIME_CAPACITY and self.frame_time_index % FRAME_TIME_CAPACITY + 1 or 1
		for i = 1, count do
			local index = (oldest + i - 2) % FRAME_TIME_CAPACITY + 1
			local x = GRAPH_X + (i - 1) / (FRAME_TIME_CAPACITY - 1) * (graph_right - GRAPH_X)
			local normalized_dt = math.min(self.frame_times[index] / self.graph_max_dt, 1)
			points[#points + 1] = x
			points[#points + 1] = graph_bottom - normalized_dt * GRAPH_HEIGHT
		end
		Painter.setColorTable(Colors.accent)
		love.graphics.line(points)
	end

	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print((
		"FPS      %4d\n" ..
		"event    %6.2f ms\n" ..
		"update   %6.2f ms\n" ..
		"draw     %6.2f ms\n" ..
		"present  %6.2f ms"
	):format(
		self.fps,
		timings.event * 1000,
		timings.update * 1000,
		timings.draw * 1000,
		timings.present * 1000
	), GRAPH_WIDTH, PADDING)
end

return FpsView
