local rbtree = require("rbtree")
local ncbt = require("ncbt")
local class = require("class")
local Visual = require("chart.chartedit.Visual")

---@class rizu.editor.NcbtContext
---@operator call: rizu.editor.NcbtContext
local NcbtContext = class()

function NcbtContext:load()
	self.onsets = nil

	self.onsetsDeltaDist = nil
	self.tempo = nil
	self.offset = nil
	self.bins = nil
	self.binsSize = nil
end

---@param soundData audio.Wave
function NcbtContext:detect(soundData)
	self.duration = soundData.getDuration and soundData:getDuration() or (soundData.samples_count / soundData.sample_rate)

	local onsets = ncbt.onsets(soundData)

	local tree = rbtree.new()
	for _, time in ipairs(onsets) do
		tree:insert(time)
	end
	self.onsets = tree

	local out = ncbt.tempo_offset(onsets)

	self.onsetsDeltaDist = out.onsetsDeltaDist
	self.tempo = out.tempo
	self.offset = out.offset
	self.bins = out.bins
	self.binsSize = out.binsSize
end

---@param layer chartedit.Layer
function NcbtContext:apply(layer)
	if not self.tempo then
		return
	end

	local beatDuration = 60 / self.tempo
	local beats = math.floor((self.duration - self.offset) / beatDuration)
	local lastOffset = beats * beatDuration + self.offset

	layer:new()
	layer.points:initDefault()
	local visual = Visual()
	layer.visuals.main = visual

	local p = layer.points:getFirstPoint()
	visual:getPoint(p)
	p._vertex:new(self.offset, beats)

	local p = layer.points:getLastPoint()
	visual:getPoint(p)
	p._vertex:new(lastOffset, 1)

end

return NcbtContext
