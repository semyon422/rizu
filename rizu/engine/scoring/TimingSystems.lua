local Timings = require("sea.chart.Timings")

---Every rizu.engine.scoring.TimingSystem by its sea.TimingsName.
local TimingSystems = {}

---@type {[sea.TimingsName]: rizu.engine.scoring.TimingSystem}
local by_name = {}
for _, module in ipairs({
	"Arbitrary", "Sphere", "Simple", "OsuMania", "Etterna", "Quaver", "LunaticRave", "Iidx", "Unknown",
}) do
	local system = require("rizu.engine.scoring.systems." .. module) --[[@as rizu.engine.scoring.TimingSystem]]
	by_name[system.name] = system
end

---The ones a player can pick to be judged with.
---@type sea.TimingsName[]
TimingSystems.selectable = {"sphere", "osuod", "etternaj", "quaver", "bmsrank", "iidx"}

---@type {[string]: true}
local is_selectable = {}
for _, name in ipairs(TimingSystems.selectable) do
	is_selectable[name] = true
end

---@param name string
---@return boolean
function TimingSystems.isSelectable(name)
	return is_selectable[name] == true
end

---The system a chart of a format is judged with when the file does not say.
---@type {[sea.ChartFormat]: sea.TimingsName}
local format_systems = {
	sphere = "sphere",
	osu = "osuod",
	o2jam = "sphere",
	bms = "bmsrank",
	stepmania = "etternaj",
	quaver = "quaver",
	midi = "sphere",
	ksm = "sphere",
	iidx = "iidx",
}

---Auto timings: how a chart is judged, decided by the chart alone. Its own timings, or its format's
---system with that system's default value, with the system's default subtimings (osu!mania: score V1).
---@param chart_timings sea.Timings?
---@param format sea.ChartFormat
---@return sea.Timings
---@return sea.Subtimings?
function TimingSystems.getAuto(chart_timings, format)
	local timings = chart_timings
	if not timings then
		local system = TimingSystems.get(assert(format_systems[format], "unknown chart format"))
		timings = Timings(system.name, system.default_value)
	end
	return timings, TimingSystems.get(timings.name).default_subtimings
end

---The system whose score systems take this kind of sea.Healths as their gauge.
---@param name sea.HealthsName
---@return rizu.engine.scoring.TimingSystem?
function TimingSystems.getByHealths(name)
	for _, system in pairs(by_name) do
		if system.healths_name == name then
			return system
		end
	end
end

---@param name sea.TimingsName
---@return rizu.engine.scoring.TimingSystem
function TimingSystems.get(name)
	return by_name[name] or error("invalid timings object")
end

return TimingSystems
