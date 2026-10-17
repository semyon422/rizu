local class = require("class")

---@class chart.SequenceAccumulator
---@operator call: chart.SequenceAccumulator
local SequenceAccumulator = class()

function SequenceAccumulator:new()
	self.sequences = {}
end

---@param sequence table
function SequenceAccumulator:add(sequence)
	table.insert(self.sequences, sequence)
end

---@return table
function SequenceAccumulator:get()
	return self.sequences
end

return SequenceAccumulator
