local FlowContainer = require("gui.layout.FlowContainer")
local Inputs = require("gui.input.Inputs")
local Screen = require("gui.Screen")
local ScrollView = require("gui.ScrollView")
local View = require("gui.View")

local test = {}

---@return gui.Screen
---@return gui.ScrollView
---@return gui.View[]
local function createScrollView()
	local rows = {}
	local content = FlowContainer({direction = "column"})
	for i = 1, 3 do
		local row = View()
		row:setSize(100, 50)
		row.handles_mouse_input = true
		content:add(row)
		rows[i] = row
	end
	content:fitContent()

	local scroll_view = ScrollView(content)
	scroll_view:anchorFixed(0, 0, 100, 50)
	local screen = Screen()
	screen.root:add(scroll_view)
	screen:resize(200, 200)
	return screen, scroll_view, rows
end

---@param t testing.T
function test.culls_content_outside_viewport(t)
	local _, _, rows = createScrollView()

	t:eq(rows[1].cull_mask, 0)
	t:assert(bit.band(rows[2].cull_mask, View.CULL_VIEWPORT) ~= 0)
	t:assert(bit.band(rows[3].cull_mask, View.CULL_VIEWPORT) ~= 0)
end

---@param t testing.T
function test.immediate_scroll_refreshes_culling(t)
	local _, scroll_view, rows = createScrollView()

	scroll_view:scrollTo(50, true)

	t:assert(bit.band(rows[1].cull_mask, View.CULL_VIEWPORT) ~= 0)
	t:eq(rows[2].cull_mask, 0)
	t:assert(bit.band(rows[3].cull_mask, View.CULL_VIEWPORT) ~= 0)
end

---@param t testing.T
function test.culled_views_do_not_receive_input(t)
	local screen, _, rows = createScrollView()
	local inputs = Inputs()
	inputs:beginFrame(25, 75)

	screen:acceptInputs(inputs)

	t:eq(#inputs.mouse_hits, 0)
	t:assert(bit.band(rows[2].cull_mask, View.CULL_VIEWPORT) ~= 0)
end

---@param t testing.T
function test.viewport_culling_preserves_other_cull_causes(t)
	local _, scroll_view, rows = createScrollView()
	local other_cause = 4
	rows[1].cull_mask = bit.bor(rows[1].cull_mask, other_cause)

	scroll_view:scrollTo(50, true)
	scroll_view:scrollTo(0, true)

	t:assert(bit.band(rows[1].cull_mask, other_cause) ~= 0)
	t:eq(bit.band(rows[1].cull_mask, View.CULL_VIEWPORT), 0)
end

return test
