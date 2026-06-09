local Fraction = require("chart.core.Fraction")
local Layer = require("chart.chartedit.Layer")
local Point = require("chart.chartedit.Point")
local Scroller = require("rizu.editor.Scroller")

local test = {}

local function createEditorModel()
	local layer = Layer()
	layer.points:initDefault()

	local editorModel = {
		layer = layer,
		session = {
			point = layer.points:getFirstPoint():clone(Point()),
		},
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

	function editorModel:setTime(time)
		self.time = time
	end

	return editorModel
end

---@param t testing.T
function test.next_snap(t)
	local editorModel = createEditorModel()
	local scroller = Scroller()
	scroller.editorModel = editorModel

	local vertex, time = scroller:getNextSnapIntervalTime(editorModel.session.point, 1)

	t:eq(vertex, editorModel.layer.points:getFirstPoint().vertex)
	t:eq(time, Fraction(1, 4))
end

---@param t testing.T
function test.scroll_time_point_alias(t)
	local editorModel = createEditorModel()
	local scroller = Scroller()
	scroller.editorModel = editorModel

	local point = editorModel.layer.points:interpolateAbsolute(4, 0.5)
	scroller:scrollTimePoint(point)

	t:eq(editorModel.time, 0.5)
	t:eq(editorModel.session.point.absoluteTime, 0.5)
end

---@param t testing.T
function test.scroll_snaps(t)
	local editorModel = createEditorModel()
	editorModel.intervalManager = {
		isGrabbed = function()
			return false
		end,
	}

	local scroller = Scroller()
	scroller.editorModel = editorModel

	scroller:scrollSnaps(1)

	t:eq(editorModel.time, 0.25)
	t:eq(editorModel.session.point.time, Fraction(1, 4))
end

return test
