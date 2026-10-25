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

---@param name sea.TimingsName
---@return rizu.engine.scoring.TimingSystem
function TimingSystems.get(name)
	return by_name[name] or error("invalid timings object")
end

return TimingSystems
