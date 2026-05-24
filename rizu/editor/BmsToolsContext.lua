local class = require("class")

---@class rizu.editor.BmsToolsContext
---@operator call: rizu.editor.BmsToolsContext
---@field offset number
---@field tempo number
---@field beat_offset number
local BmsToolsContext = class()

function BmsToolsContext:new()
	self.offset = 0
	self.tempo = 120
	self.beat_offset = 0
end

---@param layer chartedit.Layer
function BmsToolsContext:initFromLayer(layer)
	self.offset = layer.points:getFirstPoint().vertex.offset
	self.tempo = layer.points:getFirstPoint().vertex:getTempo()
	self.beat_offset = 0
end

---@param layer chartedit.Layer
function BmsToolsContext:resetOffsetTempo(layer)
	local p1 = layer.points:getFirstPoint()
	local p2 = layer.points:getLastPoint()

	if not p1 or not p2 then
		return
	end

	p1.vertex.offset = self.offset
	p2.vertex.offset = self.offset + p2:sub(p1):tonumber() * 60 / self.tempo
end

return BmsToolsContext
