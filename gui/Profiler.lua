local Profiler = {}

local REPORT_FRAMES = 120
local REPORT_LIMIT = 32

local frame_count = 0
local samples = {}

---@class gui.Profiler.Sample
---@field total number
---@field max number
---@field calls integer

---@return number
function Profiler.start()
	return love.timer.getTime()
end

---@param name string
---@param elapsed number
---@param calls integer?
---@param maximum number?
function Profiler.add(name, elapsed, calls, maximum)
	local sample = samples[name]
	if not sample then
		sample = {total = 0, max = 0, calls = 0}
		samples[name] = sample
	end
	sample.total = sample.total + elapsed
	sample.max = math.max(sample.max, maximum or elapsed)
	sample.calls = sample.calls + (calls or 1)
end

---@param name string
---@param started number
function Profiler.stop(name, started)
	Profiler.add(name, love.timer.getTime() - started)
end

---@param object table
---@return string
function Profiler.getName(object)
	if object.debug_name then
		return object.debug_name
	end
	local class = getmetatable(object)
	local name = class and rawget(class, "__name") or tostring(object)
	return name:gsub("^@", "")
end

function Profiler.finishFrame()
	frame_count = frame_count + 1
	if frame_count < REPORT_FRAMES then
		return
	end

	local rows = {}
	for name, sample in pairs(samples) do
		rows[#rows + 1] = {name = name, sample = sample}
	end
	table.sort(rows, function(a, b)
		return a.sample.total > b.sample.total
	end)

	print(("[Profile] %d frames; nested rows overlap; timer calls add overhead"):format(frame_count))
	for i = 1, math.min(#rows, REPORT_LIMIT) do
		local row = rows[i]
		local sample = row.sample
		print(("  %7.3f ms/frame  %7.3f ms max  %5.2f calls/frame  %s"):format(
			sample.total * 1000 / frame_count,
			sample.max * 1000,
			sample.calls / frame_count,
			row.name
		))
	end

	frame_count = 0
	samples = {}
end

return Profiler
