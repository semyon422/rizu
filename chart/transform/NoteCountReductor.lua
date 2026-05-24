local class = require("class")

---@class chart.NoteCountReductor
---@operator call: chart.NoteCountReductor
local NoteCountReductor = class()

local recursionLimit = 1000
local recursionDepth = 0

---@param linePairIndex number
---@param line2NoteCount number
---@return number
function NoteCountReductor:check(linePairIndex, line2NoteCount)
	local linePairs = self.linePairs
	local rate = 0

	local linePair = linePairs[linePairIndex]
	local nextLinePair = linePairs[linePairIndex + 1]

	local combination = assert(linePair.combinations[linePair.line1.reducedNoteCount][line2NoteCount])

	local delta = linePair.line1.noteCount - linePair.line2.noteCount
	local reducedDelta = linePair.line1.reducedNoteCount - line2NoteCount
	if
		math.abs(reducedDelta) - math.abs(delta) > 0 or
		reducedDelta * delta < 0
	then
		return 0
	end
	rate = rate + combination.sum
	--[[
		TODO:
		apply math.abs(reducedDelta) - math.abs(delta) > 0 only for jacked and not jacked lines, > 1? for combined
		or use soft rule?
	]]

	if recursionLimit >= 1 and nextLinePair then
		local maxNextLine2NoteCount = math.min(
			nextLinePair.line2.maxReducedNoteCount,
			self.targetMode + nextLinePair.preReducedJackCount - line2NoteCount
		)
		if maxNextLine2NoteCount == 0 then
			return 0
		end
		recursionDepth = recursionDepth - 1
		recursionLimit = recursionLimit / maxNextLine2NoteCount

		linePair.bestLine2NoteCount = line2NoteCount
		linePair.line2.reducedNoteCount = line2NoteCount

		local maxNextRate = 0
		for nextLine2NoteCount = 1, maxNextLine2NoteCount do
			maxNextRate = math.max(maxNextRate, self:check(linePairIndex + 1, nextLine2NoteCount))
		end
		rate = rate + maxNextRate

		linePair.bestLine2NoteCount = nil
		linePair.line2.reducedNoteCount = nil

		recursionDepth = recursionDepth + 1
		recursionLimit = recursionLimit * maxNextLine2NoteCount
	end

	return rate
end

---@param linePairIndex number
function NoteCountReductor:processJackCount(linePairIndex)
	local linePair = self.linePairs[linePairIndex]

	local notes = {}
	for _, laneIndex in ipairs(linePair.line1.combination) do
		notes[laneIndex] = (notes[laneIndex] or 0) + 1
	end
	for _, laneIndex in ipairs(linePair.line2.combination) do
		notes[laneIndex] = (notes[laneIndex] or 0) + 1
	end

	local jackCount = 0
	for _, count in pairs(notes) do
		if count == 2 then
			jackCount = jackCount + 1
		end
	end

	local overlapsCount = 0
	for j = 1, self.targetMode do
		if linePair.line1.overlap[j] > 0 and linePair.line2.overlap[j] > 0 then
			overlapsCount = overlapsCount + 1
		end
	end

	linePair.jackCount = jackCount
	linePair.overlapsCount = overlapsCount
	linePair.preReducedJackCount = math.min(overlapsCount, jackCount)
	if self.targetMode == 1 then
		linePair.preReducedJackCount = math.max(linePair.preReducedJackCount, 1)
	end
end

---@param linePairIndex number
function NoteCountReductor:preprocessLinePair(linePairIndex)
	local linePairs = self.linePairs
	local linePair = linePairs[linePairIndex]

	self:processJackCount(linePairIndex)
	local preReducedJackCount = linePair.preReducedJackCount

	local combinations = {}
	for j = 1, linePair.line1.maxReducedNoteCount do
		local subCombinations = {}
		combinations[j] = subCombinations
		for k = 1, linePair.line2.maxReducedNoteCount do
			if j + k <= self.targetMode + preReducedJackCount then
				local combination = {j, k}
				subCombinations[k] = combination

				local ratio = (j / k) / (linePair.line1.noteCount / linePair.line2.noteCount)
				if ratio > 1 then
					ratio = 1 / ratio -- ratio is from [0; 1], greater is better
				end

				combination.ratio = ratio
				combination.sum = j + k
			end
		end
	end
	linePair.combinations = combinations

	if #combinations == 0 then
		local subCombinations = {}
		combinations[0] = subCombinations
		for k = 1, linePair.line2.maxReducedNoteCount do
			subCombinations[k] = {
				[1] = 0,
				[2] = k,
				ratio = 1,
				sum = k,
			}
		end
	end
end

function NoteCountReductor:preprocessLinePairs()
	self.linePairs = {}
	local linePairs = self.linePairs
	local lines = self.lines
	for linePairIndex = 0, #lines - 1 do
		local linePair = {}

		linePair.index = linePairIndex
		linePair.line1 = lines[linePairIndex]
		linePair.line2 = lines[linePairIndex + 1]

		linePairs[linePairIndex] = linePair

		linePair.line1.pair1 = linePairs[linePairIndex - 1]
		linePair.line1.pair2 = linePairs[linePairIndex]
		linePair.line2.pair1 = linePairs[linePairIndex]
		linePair.line2.pair2 = linePairs[linePairIndex + 1]

		self:preprocessLinePair(linePairIndex)
	end
end

function NoteCountReductor:processLinePairs()
	local linePairs = self.linePairs
	for linePairIndex = 0, #self.linePairs do
		local linePair = linePairs[linePairIndex]
		local nextLinePair = linePairs[linePairIndex + 1]

		local maxLine2NoteCount = math.min(
			linePair.line2.maxReducedNoteCount,
			self.targetMode + linePair.preReducedJackCount - linePair.line1.reducedNoteCount,
			self.targetMode + (nextLinePair and nextLinePair.preReducedJackCount - 1 or 0)
		)

		local rateCases = {}
		for line2NoteCount = 1, maxLine2NoteCount do
			recursionLimit = recursionLimit / maxLine2NoteCount
			local rateCase = {}
			rateCase.rate = self:check(linePairIndex, line2NoteCount)
			rateCase.combination = linePair.combinations[linePair.line1.reducedNoteCount][line2NoteCount]
			rateCases[line2NoteCount] = rateCase
			recursionLimit = recursionLimit * maxLine2NoteCount
		end

		local bestLine2NoteCount = 1
		local bestCombination = rateCases[1].combination
		local bestRate = rateCases[1].rate
		for line2NoteCount = 1, maxLine2NoteCount do
			local rateCase = rateCases[line2NoteCount]
			local rate = rateCase.rate
			local combination = rateCase.combination

			if combination then
				local currentIsBetter = false
				if rate > bestRate then
					currentIsBetter = true
				elseif rate == bestRate then
					if combination.ratio ~= bestCombination.ratio then
						currentIsBetter = combination.ratio > bestCombination.ratio
					end
					if combination[1] == combination[2] and bestCombination[1] == bestCombination[2] then
						currentIsBetter = combination[1] > bestCombination[1]
					end
				end
				if currentIsBetter then
					bestLine2NoteCount = line2NoteCount
					bestRate = rate
					bestCombination = combination
				end
			end
		end

		linePair.bestLine2NoteCount = bestLine2NoteCount
		linePair.line2.reducedNoteCount = bestLine2NoteCount
		linePair.reducedJackCount = math.min(
			linePair.preReducedJackCount,
			linePair.line1.reducedNoteCount,
			linePair.line2.reducedNoteCount
		)
	end
end

---@param lines table
---@param columnCount number
---@param targetMode number
function NoteCountReductor:process(lines, columnCount, targetMode)
	self.lines = lines
	self.columnCount = columnCount
	self.targetMode = targetMode

	--[[input:
		lines = {
			{
				combination,		-- jacks
				overlap,			-- jacks
				noteCount,			-- linePair.combinations
				maxReducedNoteCount,		-- linePair.combinations
				...
			}
		}
		self.targetMode, self.columnCount
	]]

	-- print("preprocessLinePairs")
	self:preprocessLinePairs()
	-- print("processLinePairs")
	self:processLinePairs()

	--[[output
		lines = {
			{
				...
				reducedNoteCount
			}
		}
	]]
end

return NoteCountReductor
