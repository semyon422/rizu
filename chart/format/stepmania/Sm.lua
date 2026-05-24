local class = require("class")
local string_util = require("string_util")
local MsdFile = require("chart.format.stepmania.MsdFile")

---@class chart.stepmania.Sm
---@operator call: chart.stepmania.Sm
---@field header {[string]: string}
---@field bpm {[number]: number}
---@field stop {[number]: number}
local Sm = class()

function Sm:new()
	self.header = {}
	self.bpm = {}
	self.stop = {}
	self.charts = {}
end

local value_handlers = {
	BPMS = "processBPMS",
	STOPS = "processSTOPS",
	NOTES = "processNOTES",
}

---@param s string
function Sm:import(s)
	local msd = MsdFile()
	msd:read(s)

	for i = 1, msd:getNumValues() do
		local params = msd:getValue(i)
		local value_name = params[1]:upper()
		---@type function
		local handler = self[value_handlers[value_name]]
		if handler then
			handler(self, params)
		else
			self.header[value_name:upper()] = params[2]
		end
	end
end

---@param params string[]
function Sm:processBPMS(params)
	local bpms = string_util.split(params[2], ",")
	for _, v in ipairs(bpms) do
		local beat, tempo = v:match("^%s*(.+)=(.+)%s*$")
		if beat and tempo then
			table.insert(self.bpm, {
				beat = tonumber(beat),
				tempo = tonumber(tempo)
			})
			if not self.displayTempo then
				self.displayTempo = tonumber(tempo)
			end
		end
	end
end

---@param params string[]
function Sm:processSTOPS(params)
	local stops = string_util.split(params[2], ",")
	for _, v in ipairs(stops) do
		local beat, duration = v:match("^%s*(.+)=(.+)%s*$")
		if beat and duration then
			table.insert(self.stop, {
				beat = tonumber(beat),
				duration = tonumber(duration)
			})
		end
	end
end

---@param params string[]
function Sm:processNOTES(params)
	local chart = {
		measure = 0,
		offset = 0,
		mode = 0,
		notes = {},
		measure_size = {},
	}
	self.chart = chart
	table.insert(self.charts, chart)

	chart.header = {
		stepstype = params[2]:match("^%s*(.-)%s*$"),
		description = params[3]:match("^%s*(.-)%s*$"),
		difficulty = params[4]:match("^%s*(.-)%s*$"),
		meter = params[5]:match("^%s*(.-)%s*$"),
		radarvalues = params[6]:match("^%s*(.-)%s*$"),
	}

	self:processNotesParam(params[7])
end

---@param param string
function Sm:processNotesParam(param)
	local chart = self.chart
	for _, s in string_util.isplit(param, ",") do
		local count = 0
		for line in s:gmatch("([^%s]+)") do
			self:processNotesLine(string_util.trim(line))
			chart.offset = chart.offset + 1
			count = count + 1
		end
		chart.measure_size[chart.measure] = count
		chart.measure = chart.measure + 1
		chart.offset = 0
	end
end

---@param line string
function Sm:processNotesLine(line)
	local chart = self.chart
	if tonumber(line) then
		chart.mode = math.max(chart.mode, #line)
	end
	for i = 1, #line do
		local noteType = line:sub(i, i)
		if noteType ~= "0" then
			table.insert(chart.notes, {
				measure = chart.measure,
				offset = chart.offset,
				noteType = noteType,
				column = i,
			})
		end
	end
end

return Sm
