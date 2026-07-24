local class = require("class")
local Easing = require("gui.anim.Easing")

---@alias gui.layout.Padding number|{[1]: number, [2]: number, [3]: number, [4]: number}

---Cross/main-axis alignment values used by layout containers (§5).
---@alias gui.layout.Align "fill"|"start"|"center"|"end"

---Contract for layout strategies (§5). A strategy is a duck-typed object that
---arranges a container's children by writing their transient `arranged` rect
---(parent content space). Strategies never write authored state.
---
---Strategies may extend this class for the type, but it is not required —
---any table with `arrange` and `contentSize` methods satisfies the contract.
---@class gui.layout.LayoutTransition
---@field duration number
---@field easing? gui.anim.EasingName|gui.anim.Easing

---@class gui.ArrangeStrategy
---@operator call: gui.ArrangeStrategy
---@field layout_transition gui.layout.LayoutTransition?
local ArrangeStrategy = class()

---@param transition gui.layout.LayoutTransition?
function ArrangeStrategy:validateLayoutTransition(transition)
	if transition == nil then return end
	assert(type(transition) == "table", "layout_transition must be a table or nil")
	assert(type(transition.duration) == "number" and transition.duration >= 0 and transition.duration < math.huge,
		"layout_transition.duration must be finite and non-negative")
	if transition.easing ~= nil then
		Easing.resolve(transition.easing)
	end
end

---Write `child.arranged = {x, y, w, h}` for each non-`layout_ignore` child.
---Called after the container's own rect is resolved and before children
---resolve. Must be idempotent under repeated invocation.
---@param container gui.View
function ArrangeStrategy:arrange(container)
	error("not implemented")
end

---Intrinsic content size for self-sizing containers (§13.2). Measures authored
---sizes only; parent-relative specs on the measured axis are a fail-fast error.
---@param container gui.View
---@return number width
---@return number height
function ArrangeStrategy:contentSize(container)
	error("not implemented")
end

return ArrangeStrategy
