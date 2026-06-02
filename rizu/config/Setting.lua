local class = require("class")

---@class rizu.config.Setting
---@operator call: rizu.config.Setting
---@field kind string
---@field default_value any
---@field is_deferred boolean
---@field is_experemental boolean
---@field is_restart_required boolean
local Setting = class()

---@param kind string
---@param default_value any
function Setting:new(kind, default_value)
	self.kind = kind
	self.default_value = default_value
	self.is_deferred = false
	self.is_experemental = false
	self.is_restart_required = false
end

---@generic T
---@param self T
---@param is_deferred boolean?
---@return T
function Setting:setDeferred(is_deferred)
	self.is_deferred = is_deferred ~= false
	return self
end

---@generic T
---@param self T
---@param is_experemental boolean?
---@return T
function Setting:setExperemental(is_experemental)
	self.is_experemental = is_experemental ~= false
	return self
end

---@generic T
---@param self T
---@param is_restart_required boolean?
---@return T
function Setting:setRestartRequired(is_restart_required)
	self.is_restart_required = is_restart_required ~= false
	return self
end

return Setting
