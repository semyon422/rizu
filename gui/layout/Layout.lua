local Easing = require("gui.anim.Easing")

---@alias gui.layout.Padding number|{[1]: number, [2]: number, [3]: number, [4]: number}

---{left, top, right, bottom}
---@alias gui.layout.Insets {[1]: number, [2]: number, [3]: number, [4]: number}

---Cross/main-axis alignment values used by layout containers.
---@alias gui.layout.Align "fill"|"start"|"center"|"end"

---Children glide from their old position when the container moves them. Their size snaps unless
---`scale_size` is set, which glides it by scaling the child and therefore stretches its content.
---@class gui.layout.LayoutTransition
---@field duration number
---@field easing? gui.anim.EasingName|gui.anim.Easing
---@field scale_size? boolean

---Validation shared by the layout containers.
local Layout = {}

---@param value any
---@return boolean
function Layout.isFiniteNumber(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

---Validates authored padding and expands it to four insets.
---@param padding gui.layout.Padding
---@return gui.layout.Insets
function Layout.normalizePadding(padding)
	if type(padding) == "number" then
		assert(Layout.isFiniteNumber(padding) and padding >= 0,
			("padding must be a finite non-negative number (got %s)"):format(tostring(padding)))
		return {padding, padding, padding, padding}
	end
	assert(type(padding) == "table" and #padding == 4,
		"padding table must be {left, top, right, bottom}")
	for i = 1, 4 do
		assert(Layout.isFiniteNumber(padding[i]) and padding[i] >= 0,
			("padding[%d] must be a finite non-negative number (got %s)"):format(i, tostring(padding[i])))
	end
	return {padding[1], padding[2], padding[3], padding[4]}
end

---@param transition gui.layout.LayoutTransition?
function Layout.validateTransition(transition)
	if transition == nil then return end
	assert(type(transition) == "table", "layout_transition must be a table or nil")
	assert(type(transition.duration) == "number" and transition.duration >= 0 and transition.duration < math.huge,
		"layout_transition.duration must be finite and non-negative")
	if transition.easing ~= nil then
		Easing.resolve(transition.easing)
	end
	assert(transition.scale_size == nil or type(transition.scale_size) == "boolean",
		"layout_transition.scale_size must be boolean or nil")
end

return Layout
