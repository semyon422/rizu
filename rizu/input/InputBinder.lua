local class = require("class")
local InputMode = require("chart.core.InputMode")
local EventIdMapper = require("rizu.input.EventIdMapper")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

---@alias rizu.InputKey string|integer

---@class rizu.InputConfig
---@field [string] {[1]: rizu.InputKey, [2]: rizu.InputDeviceType, [3]: integer}[][]

---@class rizu.InputBinder
---@operator call: rizu.InputBinder
local InputBinder = class()

---@param config rizu.InputConfig
---@param input_mode string
function InputBinder:new(config, input_mode)
	self.config = config
	self.input_mode = input_mode

	self.mapper = EventIdMapper()

	local im = InputMode(input_mode)
	self.columns = im:getInputs()
	self.map = im:getInputMap()
end

---@param event rizu.KeyPhysicInputEvent
---@return rizu.VirtualInputEvent?
function InputBinder:transform(event)
	local config = self.config[self.input_mode]
	if not config then
		return
	end

	local key, device = event.key, event.device

	for i, binds in pairs(config) do
		for index, bind in pairs(binds) do
			local _key, d_type, d_id = unpack(bind, 1, 3)
			if _key == key and d_type == device.type and d_id == device.id then
				local id_string = table.concat({d_type, d_id, key, index}, "_")
				local event_id = self.mapper:get(id_string)
				if event.state == false then
					self.mapper:free(id_string)
				end
				return VirtualInputEvent(event_id, event.state, i, nil)
			end
		end
	end
end

---@param vkey ncdk2.Column
---@param index integer
---@param key rizu.InputKey?
---@param device rizu.InputDevice?
function InputBinder:setKey(vkey, index, key, device)
	local input_mode = self.input_mode
	local config = self.config

	config[input_mode] = config[input_mode] or {}
	local inputConfig = config[input_mode]

	local n = self.map[vkey]
	inputConfig[n] = inputConfig[n] or {}
	local binds = inputConfig[n]

	if not key then
		binds[index] = nil
		return
	end

	assert(device)
	binds[index] = {key, device.type, device.id}
end

---@param vkey ncdk2.Column
---@param index number
---@return rizu.InputKey?
---@return rizu.InputDeviceType?
---@return integer?
function InputBinder:getKey(vkey, index)
	local config = self.config[self.input_mode]
	if not config then
		return
	end

	local n = self.map[vkey]

	local bind = config[n] and config[n][index]
	if not bind then
		return
	end

	local _key, device_type, device_id = unpack(bind)
	return _key, device_type, device_id
end

---@return number
function InputBinder:getBindsCount()
	local config = self.config[self.input_mode]
	if not config then
		return 0
	end

	local max_index = 0

	for _, binds in pairs(config) do
		for i in ipairs(binds) do
			max_index = math.max(max_index, i)
		end
	end

	return max_index
end

function InputBinder:reset()
	self.config[self.input_mode] = {}
end

return InputBinder
