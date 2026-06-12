local EditorCursorState = require("rizu.editor.EditorCursorState")
local Point = require("chart.chartedit.Point")

local test = {}

---@param t testing.T
function test.defaults_to_empty_point(t)
	local cursorState = EditorCursorState()

	t:ne(cursorState:getPoint(), nil)
	t:eq(cursorState:getPoint(), cursorState.point)
end

---@param t testing.T
function test.set_point_clones_into_stable_point(t)
	local cursorState = EditorCursorState()
	local storedPoint = cursorState:getPoint()
	local point = Point()
	point.absoluteTime = 1.25

	cursorState:setPoint(point)

	t:eq(cursorState:getPoint(), storedPoint)
	t:eq(cursorState:getTime(), 1.25)
end

return test
