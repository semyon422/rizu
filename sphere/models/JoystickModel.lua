local class = require("class")
local table_util = require("table_util")
local Settings = require("rizu.config.Settings")
local AnalogScratch = require("chart.transform.AnalogScratch")
local ScratchMapper = require("chart.transform.ScratchMapper")

---@class sphere.JoystickModel
---@operator call: sphere.JoystickModel
local JoystickModel = class()

---@param settings rizu.config.Config
function JoystickModel:new(settings)
	self.data = {}
	self.settings = settings
end

function JoystickModel:getScratchState(id, axis, joystick)
	local data = self.data
	data[id] = data[id] or {}
	if data[id][axis] then
		return data[id][axis]
	end

	local keys = Settings.keys.gameplay
	local settings = self.settings
	local cfg = {
		act_period = settings:getNumber(keys.analog_scratch_act_period),
		deact_period = settings:getNumber(keys.analog_scratch_deact_period),
		act_w = settings:getNumber(keys.analog_scratch_act_w),
		deact_w = settings:getNumber(keys.analog_scratch_deact_w),
	}

	local analogScratch = AnalogScratch(cfg.act_period, cfg.deact_period, cfg.act_w, cfg.deact_w)
	local scratchMapper = ScratchMapper(analogScratch, function(state, is_right)
		local key = ("%s%s"):format(is_right and "+" or "-", axis)
		local name = state and "joystickpressed" or "joystickreleased"
		love.event.push(name, joystick, key)
	end)
	data[id][axis] = {
		analogScratch = analogScratch,
		scratchMapper = scratchMapper,
	}

	return data[id][axis]
end

function JoystickModel:receive(event)
	if event.name ~= "joystickaxis" then
		return
	end
	local joystick, axis, value = unpack(event)
	local id = joystick:getID()

	local state = self:getScratchState(id, axis, joystick)
	state.value = value
end

function JoystickModel:update(dt)
	for id, d in pairs(self.data) do
		for axis, state in pairs(d) do
			state.analogScratch:update(state.value, dt)
			state.scratchMapper:update()
		end
	end
end

return JoystickModel
