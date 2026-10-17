local Fraction = require("chart.core.Fraction")
local Layer = require("chart.chartedit.Layer")
local Point = require("chart.chartedit.Point")
local Scroller = require("rizu.editor.timing.Scroller")

local test = {}

local function createEditorModel()
	local layer = Layer()
	layer.points:initDefault()

	local editorModel = {
		layer = layer,
		point = layer.points:getFirstPoint():clone(Point()),
		settings = {
			snap = 4,
		},
	}

	function editorModel:getSettings()
		return self.settings
	end

	function editorModel:getDtpAbsolute(time)
		return self.layer.points:interpolateAbsolute(self.settings.snap, time)
	end

	function editorModel:getSessionTime()
		return self.point.absoluteTime
	end

	function editorModel:getPoint()
		return self.point
	end

	function editorModel:setSessionPoint(point)
		self.setSessionPointCount = (self.setSessionPointCount or 0) + 1
		point:clone(self.point)
	end

	function editorModel:setTime(time)
		self.time = time
	end

	return editorModel
end

local function createScroller(editorModel)
	local scroller = Scroller()
	local context = {}

	function context:getDtpAbsolute(time)
		return editorModel:getDtpAbsolute(time)
	end

	function context:getSessionTime()
		return editorModel:getSessionTime()
	end

	function context:getPoint()
		return editorModel:getPoint()
	end

	function context:setSessionPoint(point)
		editorModel:setSessionPoint(point)
	end

	function context:setTime(time)
		editorModel:setTime(time)
	end

	function context:isIntervalGrabbed()
		return editorModel.intervalManager:isGrabbed()
	end

	function context:interpolateFraction(vertex, time)
		return editorModel.layer.points:interpolateFraction(vertex, time)
	end

	function context:getSettings()
		return editorModel:getSettings()
	end

	scroller:setContext(context)
	return scroller
end

---@param t testing.T
function test.next_snap(t)
	local editorModel = createEditorModel()
	local scroller = createScroller(editorModel)

	local vertex, time = scroller:getNextSnapIntervalTime(editorModel:getPoint(), 1)

	t:eq(vertex, editorModel.layer.points:getFirstPoint().vertex)
	t:eq(time, Fraction(1, 4))
end

---@param t testing.T
function test.scroll_time_point_alias(t)
	local editorModel = createEditorModel()
	local scroller = createScroller(editorModel)

	local point = editorModel.layer.points:interpolateAbsolute(4, 0.5)
	scroller:scrollTimePoint(point)

	t:eq(editorModel.time, 0.5)
	t:eq(editorModel:getPoint().absoluteTime, 0.5)
	t:eq(editorModel.setSessionPointCount, 1)
end

---@param t testing.T
function test.scroll_snaps(t)
	local editorModel = createEditorModel()
	editorModel.intervalManager = {
		isGrabbed = function()
			return false
		end,
	}

	local scroller = createScroller(editorModel)

	scroller:scrollSnaps(1)

	t:eq(editorModel.time, 0.25)
	t:eq(editorModel:getPoint().time, Fraction(1, 4))
end

---@param t testing.T
function test.scroll_seconds_delta_uses_session_time(t)
	local editorModel = createEditorModel()
	local scroller = createScroller(editorModel)

	scroller:scrollSeconds(0.5)
	scroller:scrollSecondsDelta(0.25)

	t:eq(editorModel.time, 0.75)
	t:eq(editorModel:getPoint().absoluteTime, 0.75)
end

---@param t testing.T
function test.scroll_snaps_ignored_while_interval_grabbed(t)
	local editorModel = createEditorModel()
	editorModel.intervalManager = {
		isGrabbed = function()
			return true
		end,
	}

	local scroller = createScroller(editorModel)

	scroller:scrollSnaps(1)

	t:eq(editorModel.time, nil)
	t:eq(editorModel:getPoint().absoluteTime, 0)
end

return test
