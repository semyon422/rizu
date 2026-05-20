local class = require("class")
local Sm = require("chart.format.stepmania.Sm")
local MsdFile = require("chart.format.stepmania.MsdFile")

---@class chart.stepmania.Ssc
---@operator call: chart.stepmania.Ssc
---@field header {[string]: string}
---@field bpm {[number]: number}
---@field stop {[number]: number}
local Ssc = class()

function Ssc:new()
	self.header = {}
	self.bpm = {}
	self.stop = {}
	self.charts = {}
end

Ssc.processBPMS = Sm.processBPMS
Ssc.processSTOPS = Sm.processSTOPS
Ssc.processNotesLine = Sm.processNotesLine

local value_handlers = {
	BPMS = "processBPMS",
	STOPS = "processSTOPS",
}

---@param s string
function Ssc:decode(s)
	local msd = MsdFile()
	msd:read(s)
	self:decodeMsd(msd)
end

---@param msd chart.stepmania.MsdFile
function Ssc:decodeMsd(msd)
	local state = "GETTING_SONG_INFO"
	local values = msd:getNumValues()

	local chart = {}

	for i = 1, values do
		local params = msd:getValue(i)
		local value_name = params[1]:upper()

		if state == "GETTING_SONG_INFO" then
			---@type function
			local handler = self[value_handlers[value_name]]
			if handler then
				handler(self, params)
			elseif value_name == "NOTEDATA" then
				state = "GETTING_STEP_INFO"
				chart = {
					measure = 0,
					offset = 0,
					mode = 0,
					notes = {},
					measure_size = {},
					header = {},
				}
				self.chart = chart
				table.insert(self.charts, chart)
			else
				self.header[value_name:upper()] = params[2]
			end
		elseif state == "GETTING_STEP_INFO" then
			if value_name == "NOTES" or value_name == "NOTES2" then
				state = "GETTING_SONG_INFO"
				Sm.processNotesParam(self, params[2])
			elseif value_name == "STEPFILENAME" then
			else
				chart.header[value_name:lower()] = params[2]
			end
		end
	end
end

return Ssc
