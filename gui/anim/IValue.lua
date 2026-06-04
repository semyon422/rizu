local class = require("class")

---@alias gui.anim.ValueMode "tween"|"spring"
---@alias gui.anim.ValueEasingName "linear"|"inQuad"|"outQuad"|"inOutQuad"|"outCubic"|"inOutCubic"
---@alias gui.anim.ValueEasing gui.anim.ValueEasingName|fun(t: number): number

---@class gui.anim.IValue
---@operator call: gui.anim.IValue
---@field mode gui.anim.ValueMode
---@field value number
---@field target number
---@field velocity number
local IValue = class()

---@param target number
---@return self
function IValue:set(target)
	error("not implemented")
end

---@param value? number
---@return self
function IValue:snap(value)
	error("not implemented")
end

---@return number
function IValue:get()
	error("not implemented")
end

---@return boolean
function IValue:isAnimating()
	error("not implemented")
end

---@param dt number
---@return number
function IValue:update(dt)
	error("not implemented")
end

return IValue
