local class = require("class")
local string_util = require("string_util")

---@class chart.osu.Addition
---@operator call: chart.osu.Addition
---@field sampleSet number
---@field addSampleSet number
---@field customSample number
---@field volume number
---@field sampleFile string
local Addition = class()

Addition.sampleSet = 0
Addition.addSampleSet = 0
Addition.customSample = 0
Addition.volume = 0
Addition.sampleFile = ""

---@param s string
function Addition:new(s)
	if not s then
		return
	end
	local a = string_util.split(s, ":")
	self.sampleSet = tonumber(a[1])
	self.addSampleSet = tonumber(a[2])
	self.customSample = tonumber(a[3])
	self.volume = tonumber(a[4])
	self.sampleFile = a[5]
end

---@return string
function Addition:encode()
	return ("%s:%s:%s:%s:%s"):format(
		self.sampleSet,
		self.addSampleSet,
		self.customSample,
		self.volume,
		self.sampleFile
	)
end

return Addition
