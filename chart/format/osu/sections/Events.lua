local Section = require("chart.format.osu.sections.Section")
local table_util = require("table_util")
local string_util = require("string_util")

---@class chart.osu.EventSample
---@field time integer
---@field name string
---@field volume integer

---@class chart.osu.Events: chart.osu.Section
---@operator call: chart.osu.Events
---@field samples chart.osu.EventSample[]
local Events = Section + {}

Events.add_comments = false

local EventTypes = {
	Background = 0,
	Video = 1,
	Break = 2,
	Colour = 3,
	Sprite = 4,
	Sample = 5,
	Animation = 6,
}

---@param add_comments boolean
function Events:new(add_comments)
	self.add_comments = add_comments
	self.samples = {}
end

local quoted_pattern = '^"?(.-)"?$'

---@param line string
function Events:decodeLine(line)
	---@type string[]
	local split = string_util.split(line, ",")

	-- comma is not allowed in file names
	-- osu uses split(",") and we will use

	local event_type = table_util.keyofenum(EventTypes, split[1])
	if event_type == "Background" then
		self.background = split[3]:match(quoted_pattern)
	elseif event_type == "Video" then
		self.video = {
			time = tonumber(split[2]) or 0,
			name = split[3]:match(quoted_pattern),
		}
	elseif event_type == "Sample" then  -- split[3] is layer, unused
		table.insert(self.samples, {
			time = tonumber(split[2]) or 0,
			name = split[4]:match(quoted_pattern),
			volume = tonumber(split[5]) or 100,
		})
	end
end

---@return string[]
function Events:encode()
	local out = {}

	local add_comments = self.add_comments

	if add_comments then
		table.insert(out, "//Background and Video events")
	end
	if self.background then
		table.insert(out, ('%s,0,"%s",0,0'):format(EventTypes.Background, self.background))
	end
	if self.video then
		table.insert(out, ('%s,%s,"%s"'):format(EventTypes.Video, self.video.time, self.video.name))
	end

	if add_comments then
		table.insert(out, "//Break Periods")
		table.insert(out, "//Storyboard Layer 0 (Background)")
		table.insert(out, "//Storyboard Layer 1 (Fail)")
		table.insert(out, "//Storyboard Layer 2 (Pass)")
		table.insert(out, "//Storyboard Layer 3 (Foreground)")
		table.insert(out, "//Storyboard Layer 4 (Overlay)")
		table.insert(out, "//Storyboard Sound Samples")
	end

	for _, s in ipairs(self.samples) do
		table.insert(out, ('%s,%s,%s,"%s",%s'):format(EventTypes.Sample, s.time, 0, s.name, s.volume))
	end

	return out
end

return Events
