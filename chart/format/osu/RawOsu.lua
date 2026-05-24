local class = require("class")
local string_util = require("string_util")
local GeneralSection = require("chart.format.osu.sections.GeneralSection")
local EditorSection = require("chart.format.osu.sections.EditorSection")
local MetadataSection = require("chart.format.osu.sections.MetadataSection")
local DifficultySection = require("chart.format.osu.sections.DifficultySection")
local Events = require("chart.format.osu.sections.Events")
local TimingPoints = require("chart.format.osu.sections.TimingPoints")
local HitObjects = require("chart.format.osu.sections.HitObjects")

---@class chart.osu.RawOsu
---@operator call: chart.osu.RawOsu
local RawOsu = class()

--[[
	this class should behave as follows:
	1) take any chart X
	2) open it in osu editor and save as chart Y
	3) RawOsu():decode(X):encode() should be equal Y
]]

local sections_order = {
	"General",
	"Editor",
	"Metadata",
	"Difficulty",
	"Events",
	"TimingPoints",
	"HitObjects",
}

function RawOsu:new()
	self.General = GeneralSection()
	self.Editor = EditorSection()
	self.Metadata = MetadataSection()
	self.Difficulty = DifficultySection()
	self.Events = Events(true)
	self.TimingPoints = TimingPoints()
	self.HitObjects = HitObjects()
end

---@param s string
function RawOsu:decode(s)
	for _, line in string_util.isplit(s:gsub("\r\n?", "\n"), "\n") do
		self:decodeLine(line)
	end
	self.TimingPoints:sort()
end

---@param line string
function RawOsu:decodeLine(line)
	if line:find("^%[") then
		local sectionName = line:match("^%[(.+)%]$")
		self.sectionName = sectionName
		return
	end

	if #line == 0 or line:find("^ ") or line:find("^_") or line:find("^//") then
		return
	end

	local section = self[self.sectionName]
	if not section then
		return
	end
	section:decodeLine(line)
end

---@return string
function RawOsu:encode()
	local out = {}

	table.insert(out, "osu file format v14")
	for _, section_name in ipairs(sections_order) do
		table.insert(out, "")
		table.insert(out, ("[%s]"):format(section_name))
		local section = self[section_name]
		for _, line in ipairs(section:encode()) do
			table.insert(out, line)
		end
	end

	return table.concat(out, "\r\n")
end

return RawOsu
