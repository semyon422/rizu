local class = require("class")

---@class gui.input.KeyBinding
---@field key love.KeyConstant|string
---@field control boolean?
---@field shift boolean?
---@field alt boolean?
---@field super boolean?
---@field allow_repeat boolean?

---@class gui.input.ActionMap
---@operator call: gui.input.ActionMap
---@field private actions {[string]: gui.input.KeyBinding[]}
local ActionMap = class()

---@param binding gui.input.KeyBinding
---@return gui.input.KeyBinding
local function copyBinding(binding)
	assert(type(binding) == "table", "binding must be a table")
	assert(type(binding.key) == "string" and binding.key ~= "", "binding key must be a non-empty string")
	return {
		key = binding.key,
		control = binding.control == true,
		shift = binding.shift == true,
		alt = binding.alt == true,
		super = binding.super == true,
		allow_repeat = binding.allow_repeat == true,
	}
end

function ActionMap:new()
	---@type {[string]: gui.input.KeyBinding[]}
	self.actions = {}
end

---@param action string
---@param bindings gui.input.KeyBinding[]
function ActionMap:defineAction(action, bindings)
	assert(type(action) == "string" and action ~= "", "action must be a non-empty string")
	assert(type(bindings) == "table", "bindings must be a table")
	local copied = {} ---@type gui.input.KeyBinding[]
	for i, binding in ipairs(bindings) do
		copied[i] = copyBinding(binding)
	end
	self.actions[action] = copied
end

---@param action string
---@param binding gui.input.KeyBinding
function ActionMap:addBinding(action, binding)
	local bindings = assert(self.actions[action], "undefined action: " .. tostring(action))
	bindings[#bindings + 1] = copyBinding(binding)
end

---@param action string
---@return gui.input.KeyBinding[]
function ActionMap:getBindings(action)
	local bindings = assert(self.actions[action], "undefined action: " .. tostring(action))
	local copied = {} ---@type gui.input.KeyBinding[]
	for i, binding in ipairs(bindings) do
		copied[i] = copyBinding(binding)
	end
	return copied
end

---@return fun(table: {[string]: gui.input.KeyBinding[]}, action: string): string, gui.input.KeyBinding[]
---@return {[string]: gui.input.KeyBinding[]}
function ActionMap:iterate()
	return pairs(self.actions)
end

---@param binding gui.input.KeyBinding
---@param modifiers gui.ModifierKeys|table
---@return boolean
function ActionMap:bindingMatchesModifiers(binding, modifiers)
	return (modifiers.control == true) == (binding.control == true)
		and (modifiers.shift == true) == (binding.shift == true)
		and (modifiers.alt == true) == (binding.alt == true)
		and (modifiers.super == true) == (binding.super == true)
end

---@param action string
---@param index integer?
---@return string
function ActionMap:getBindingLabel(action, index)
	local bindings = assert(self.actions[action], "undefined action: " .. tostring(action))
	local binding = assert(bindings[index or 1], "action has no binding at that index")
	local parts = {} ---@type string[]
	if binding.control then parts[#parts + 1] = "Ctrl" end
	if binding.shift then parts[#parts + 1] = "Shift" end
	if binding.alt then parts[#parts + 1] = "Alt" end
	if binding.super then parts[#parts + 1] = "Super" end
	parts[#parts + 1] = binding.key
	return table.concat(parts, "+")
end

return ActionMap
