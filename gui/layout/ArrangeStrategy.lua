local class = require("class")

---Cross/main-axis alignment values used by Stack and Flex (§5.2).
---@alias gui.layout.Align "fill"|"start"|"center"|"end"

---Contract for layout strategies (§5). A strategy is a duck-typed object that
---arranges a container's children by writing their transient `arranged` rect
---(parent content space). Strategies never write authored state.
---
---Strategies may extend this class for the type, but it is not required —
---any table with `arrange` and `contentSize` methods satisfies the contract.
---@class gui.ArrangeStrategy
---@operator call: gui.ArrangeStrategy
local ArrangeStrategy = class()

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
