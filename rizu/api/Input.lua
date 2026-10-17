local Events = require("rizu.api.Events")
local InputBinder = require("rizu.input.InputBinder")
local InputDevice = require("rizu.input.InputDevice")

--[[
Which keys play which columns.

	local input = ui.api.input
	for _, column in ipairs(input:getColumns("7key")) do
		local key = input:getBinding("7key", column, 1)
	end
	input:setBinding("7key", "key1", 1, "a", "keyboard", 1)

A column can have several keys ("slots"), counted from 1. Keyboard keys are scancodes.
Changes are saved at once.
]]

---@alias rizu.api.Input.Event
---| "bindings_changed" # A key was set, cleared or reset. Arguments: input_mode.

---@class rizu.api.Input : rizu.api.Events
---@operator call: rizu.api.Input
---@field on fun(self: rizu.api.Input, event: rizu.api.Input.Event, f: function): fun()
---@field game sphere.GameController
local Input = Events + {}

---@param self rizu.api.Input
---@param input_mode string
---@return rizu.InputBinder
local function binder(self, input_mode)
	return InputBinder(self.game.configModel.configs.input, input_mode)
end

---@param self rizu.api.Input
---@param input_mode string
local function changed(self, input_mode)
	self.game.configModel:write("input")
	self:emit("bindings_changed", input_mode)
end

---@param game sphere.GameController
function Input:new(game)
	Events.new(self)
	self.game = game
end

---The input mode of the selected chart, as the next play will have it.
---@return string? input_mode nil when no chart is selected
function Input:getInputMode()
	local mode = tostring(self.game.modifierCoordinator.state.inputMode or "")
	return mode ~= "" and mode or nil
end

---@param input_mode string "4key", "7key2scratch", ...
---@return string[] columns In display order.
function Input:getColumns(input_mode) return binder(self, input_mode).columns end

---How many keys a column can have.
---@param column string
---@return integer
function Input:getSlotCount(column)
	return column:match("^scratch%d+$") and 2 or 1
end

---@param input_mode string
---@param column string
---@param slot integer
---@return string|integer? key nil when the slot is empty
---@return rizu.InputDeviceType? device_type
---@return integer? device_id
function Input:getBinding(input_mode, column, slot)
	return binder(self, input_mode):getKey(column, slot)
end

---@param input_mode string
---@param column string
---@param slot integer
---@param key string|integer
---@param device_type rizu.InputDeviceType
---@param device_id integer
function Input:setBinding(input_mode, column, slot, key, device_type, device_id)
	binder(self, input_mode):setKey(column, slot, key, InputDevice(device_type, device_id))
	changed(self, input_mode)
end

---@param input_mode string
---@param column string
---@param slot integer
function Input:clearBinding(input_mode, column, slot)
	binder(self, input_mode):setKey(column, slot)
	changed(self, input_mode)
end

---Removes every key of the input mode.
---@param input_mode string
function Input:resetBindings(input_mode)
	binder(self, input_mode):reset()
	changed(self, input_mode)
end

return Input
