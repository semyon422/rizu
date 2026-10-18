local Events = require("rizu.api.Events")
local ColumnsOrder = require("sea.chart.ColumnsOrder")

---`rizu.api.Play` that remembers what was set and starts nothing.
---@class rizu.api.fake.FakePlay : rizu.api.Events
---@operator call: rizu.api.fake.FakePlay
local FakePlay = Events + {}

local ranges = {linear = {0.25, 4, 0.05}, exp = {-20, 20, 1}}

function FakePlay:new()
	Events.new(self)
	self.rate = 1
	self.rate_type = "linear"
	self.toggles = {constant_scroll = false, taps_only = false, nearest_input = false, auto_timings = true}
	self.timing_system = "sphere"
	self.timing_values = {osuod = 8, etternaj = 4, bmsrank = 3}
	self.osu_score_version = 1
	self.mutators = {} ---@type {name: string, value: integer?}[]
	self.mutator_position = 1
	self.input_mode = "7key"
	self.columns_order = nil ---@type integer[]?
end

function FakePlay:getRate() return self.rate end
function FakePlay:getRateType() return self.rate_type end
function FakePlay:getRateTypes() return {"linear", "exp"} end

function FakePlay:getRateValue()
	local value = self.rate
	if self.rate_type == "exp" then
		value = math.floor(math.log(self.rate) / math.log(2) * 10 + 0.5)
	end
	return value, unpack(ranges[self.rate_type])
end

function FakePlay:setRateValue(value)
	local range = ranges[self.rate_type]
	value = math.max(range[1], math.min(value, range[2]))
	self.rate = self.rate_type == "exp" and 2 ^ (value / 10) or value
	self:emit("rate_changed")
end

function FakePlay:changeRate(steps)
	local value, _, _, step = self:getRateValue()
	self:setRateValue(value + steps * step)
end

function FakePlay:setRateType(rate_type)
	self.rate_type = rate_type
	self:emit("rate_changed")
end

function FakePlay:getToggle(toggle) return self.toggles[toggle] end

function FakePlay:setToggle(toggle, on)
	self.toggles[toggle] = on
	self:emit("mods_changed")
end

function FakePlay:getModCount()
	return (self.toggles.constant_scroll and 1 or 0) + (self.toggles.taps_only and 1 or 0)
end

function FakePlay:getColumnOrder()
	local order = {} ---@type integer[]
	for i = 1, ColumnsOrder(self.input_mode).inputMode:getColumns() do
		order[i] = self.columns_order and self.columns_order[i] or i
	end
	return order
end

function FakePlay:setColumnOrder(order)
	self.columns_order = ColumnsOrder(self.input_mode, order):export()
	self:emit("mods_changed")
end

function FakePlay:mirrorColumns(side)
	self.columns_order = ColumnsOrder(self.input_mode, self.columns_order):mirror(side):export()
	self:emit("mods_changed")
end

function FakePlay:randomizeColumns(side)
	self.columns_order = ColumnsOrder(self.input_mode, self.columns_order):random(side):export()
	self:emit("mods_changed")
end

function FakePlay:getColumnOrderState()
	local name = ColumnsOrder(self.input_mode, self.columns_order):getName()
	if not name then return "original" end
	local shift = name:match("^shift (%-?%d+)$")
	if shift then return "shift", tonumber(shift) end
	return (name:gsub(" ", "_"))
end

local available = {"Mirror", "Random", "Shift", "NoLongNote"}

function FakePlay:getAvailableMutators() return available end

function FakePlay:canAddMutator(name)
	for _, mutator in ipairs(self.mutators) do
		if name == "NoLongNote" and mutator.name == name then return false end
	end
	return true
end

function FakePlay:getMutatorCount() return #self.mutators end
function FakePlay:getMutators() return self.mutators end
function FakePlay:getMutatorName(mutator) return mutator.name end
function FakePlay:hasMutatorValue(mutator) return mutator.value ~= nil end
function FakePlay:getMutatorValueText(mutator) return mutator.value and tostring(mutator.value) or nil end

function FakePlay:addMutator(name)
	if not self:canAddMutator(name) then return end
	table.insert(self.mutators, self.mutator_position, {name = name, value = name == "Shift" and 1 or nil})
	self.mutator_position = self.mutator_position + 1
	self:emit("mods_changed")
end

function FakePlay:removeMutator(index)
	table.remove(self.mutators, index)
	self.mutator_position = math.min(self.mutator_position, #self.mutators + 1)
	self:emit("mods_changed")
end

function FakePlay:changeMutatorValue(index, steps)
	local mutator = self.mutators[index]
	if not mutator or mutator.value == nil then return false end
	local value = math.max(0, math.min(mutator.value + steps, 9))
	if value == mutator.value then return false end
	mutator.value = value
	self:emit("mods_changed")
	return true
end

function FakePlay:getMutatorPosition() return self.mutator_position end

function FakePlay:setMutatorPosition(position)
	self.mutator_position = math.max(1, math.min(position, #self.mutators + 1))
end

function FakePlay:getTimingSystems() return {"sphere", "osuod", "etternaj", "quaver", "bmsrank", "iidx"} end
function FakePlay:getTimingSystem() return self.timing_system end

function FakePlay:setTimingSystem(system)
	self.timing_system = system
	self:emit("mods_changed")
end

function FakePlay:getTimingValue() return self.timing_values[self.timing_system] or 0 end

function FakePlay:setTimingValue(value)
	self.timing_values[self.timing_system] = value
	self:emit("mods_changed")
end

function FakePlay:getOsuScoreVersion() return self.osu_score_version end

function FakePlay:setOsuScoreVersion(version)
	self.osu_score_version = version
	self:emit("mods_changed")
end

function FakePlay:hasLocalReplays() return false end

function FakePlay:start(options, f) f(false, "There is no game to play in.") end

return FakePlay
