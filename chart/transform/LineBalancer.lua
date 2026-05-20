local class = require("class")
local enps = require("chart.scoring.enps")

---@class chart.LineBalancer
---@operator call: chart.LineBalancer
local LineBalancer = class()

---@param n number
---@return number
local function factorial(n)
	return n == 0 and 1 or n * factorial(n - 1)
end

---@param n number
---@param k number
---@return number
local function getCombinationsCount(n, k)
	return factorial(n) / (factorial(k) * factorial(n - k))
end

---@param a table
---@param n number
---@param k number
---@return table?
local function nextCombination(a, n, k)
	local b = {}

	for i = 1, k do
		b[i] = a[i]
	end
	b[k + 1] = n + 1

	local i = k
	while i >= 1 and b[i + 1] - b[i] < 2 do
		i = i - 1
	end

	if i >= 1 then
		b[i] = b[i] + 1
		for j = i + 1, k do
			b[j] = b[j - 1] + 1
		end
		b[k + 1] = nil
		return b
	end
end

function LineBalancer:createLineCombinationsTable()
	local lineCombinationsTable = {}

	for noteCount = 1, self.targetMode do
		local combinations = {}
		lineCombinationsTable[noteCount] = combinations

		local combination = {}
		for j = 1, noteCount do
			combination[j] = j
		end

		while combination do
			combinations[#combinations + 1] = combination
			combination = nextCombination(combination, self.targetMode, noteCount)
		end
	end
	self.lineCombinationsTable = lineCombinationsTable
end

function LineBalancer:createLineCombinationsMap()
	local lineCombinationsTable = self.lineCombinationsTable

	local lineCombinationsMap = {}
	for noteCount = 1, self.targetMode do
		local combinations = {}
		lineCombinationsMap[noteCount] = combinations
		for lineCombinationIndex = 1, #lineCombinationsTable[noteCount] do
			local combination = lineCombinationsTable[noteCount][lineCombinationIndex]
			local map = {}
			for i = 1, #combination do
				map[combination[i]] = 1
			end
			for i = 1, self.targetMode do
				map[i] = map[i] or 0
			end
			combinations[lineCombinationIndex] = map
		end
	end

	self.lineCombinationsMap = lineCombinationsMap
end

function LineBalancer:createLineCombinationsCountTable()
	local lineCombinationsCountTable = {}
	for noteCount = 1, self.targetMode do
		lineCombinationsCountTable[noteCount] = getCombinationsCount(self.targetMode, noteCount)
	end
	self.lineCombinationsCountTable = lineCombinationsCountTable
end

---@param combinationMap table
---@param overlap table
---@return number
function LineBalancer:overDiff(combinationMap, overlap)
	local sum = 0

	for i = 1, #overlap do
		sum = sum + math.abs(
			overlap[i] - combinationMap[i]
		)
	end

	return sum
end

---@param time number
---@return table
function LineBalancer:lineExpDensities(time)
	local densityStacks = self.densityStacks

	local densities = {}
	for i = 1, self.targetMode do
		local stack = densityStacks[i]
		local stackObject = stack[#stack]
		densities[i] = enps.expDensity((time - stackObject[1]) / 1000, stackObject[2])
	end

	return densities
end

local recursionLimit = 100
local recursionDepth = 0

---@param lineIndex number
---@param lineCombinationIndex number
---@return number
function LineBalancer:checkLine(lineIndex, lineCombinationIndex)
	local lines = self.lines
	local lineCombinationsMap = self.lineCombinationsMap
	local lineCombinationsTable = self.lineCombinationsTable
	local line = lines[lineIndex]

	if not line then
		return 1
	end

	local columns = lineCombinationsTable[line.reducedNoteCount][lineCombinationIndex]
	local combinationMap = lineCombinationsMap[line.reducedNoteCount][lineCombinationIndex]

	assert(#columns == line.reducedNoteCount)

	local targetMode = self.targetMode

	local prevLine = lines[lineIndex - 1]
	if lineIndex - 1 ~= 0 and prevLine then
		local prevLineCombinationIndex = prevLine.appliedLineCombinationIndex or prevLine.bestLineCombinationIndex
		local columnNotesPrev = lineCombinationsMap[prevLine.reducedNoteCount][prevLineCombinationIndex]

		local reducedJackCount = line.pair1.reducedJackCount
		if reducedJackCount == 0 then
			for i = 1, targetMode do
				if combinationMap[i] == columnNotesPrev[i] and combinationMap[i] == 1 then
					return 0
				end
			end
		else
			local hasJack = false
			local actualJackCount = 0
			for i = 1, targetMode do
				if combinationMap[i] == columnNotesPrev[i] and combinationMap[i] == 1 then
					hasJack = true
					actualJackCount = actualJackCount + 1
				end
			end
			if not hasJack then
				return 0
			end

			local jackCount = line.pair1.jackCount
			if
				actualJackCount > reducedJackCount or
				actualJackCount / line.reducedNoteCount < 1 and jackCount / #line.combination == 1 or -- see NoteCountReductor.check
				actualJackCount / reducedJackCount < jackCount / #line.combination -- doubtful
			then
				return 0
			end
		end
	end

	local densitySum = 0

	local time = line.time
	local lineExpDensities = self:lineExpDensities(time)
	local densityStacks = self.densityStacks
	for i = 1, targetMode do
		if combinationMap[i] == 1 then
			local stack = densityStacks[i]
			stack[#stack + 1] = {
				time,
				lineExpDensities[i]
			}
			densitySum = densitySum + lineExpDensities[i]
		end
	end

	local overDiff = self:overDiff(combinationMap, line.overlap)

	local rate = 1
	if overDiff > 0 then
		rate = rate * (1 / overDiff)
	end
	if densitySum > 0 then
		rate = rate * (1 / densitySum)
	end

	local nextLine = lines[lineIndex + 1]
	if recursionLimit >= 1 and nextLine then
		local combinationsCount = self.lineCombinationsCountTable[nextLine.reducedNoteCount]

		recursionDepth = recursionDepth - 1
		recursionLimit = recursionLimit / combinationsCount

		line.appliedLineCombinationIndex = lineCombinationIndex

		local maxNextRate = 0
		for i = 1, combinationsCount do
			maxNextRate = math.max(maxNextRate, self:checkLine(lineIndex + 1, i))
		end
		rate = rate * maxNextRate

		line.appliedLineCombinationIndex = nil

		recursionDepth = recursionDepth + 1
		recursionLimit = recursionLimit * combinationsCount
	end

	for i = 1, targetMode do
		if combinationMap[i] == 1 then
			local stack = densityStacks[i]
			stack[#stack] = nil
		end
	end

	return rate
end

function LineBalancer:balanceLines()
	local densityStacks = {}
	self.densityStacks = densityStacks

	for i = 1, self.targetMode do
		densityStacks[i] = {{-math.huge, 0}}
	end

	local lines = self.lines

	for lineIndex, line in ipairs(lines) do
		local lineCombinationsCount = self.lineCombinationsCountTable[line.reducedNoteCount]

		local rates = {}
		for lineCombinationIndex = 1, lineCombinationsCount do
			recursionLimit = recursionLimit / lineCombinationsCount
			rates[lineCombinationIndex] = self:checkLine(lineIndex, lineCombinationIndex)
			recursionLimit = recursionLimit * lineCombinationsCount
		end

		local bestLineCombinationIndex
		local bestRate = 0
		for lineCombinationIndex = 1, lineCombinationsCount do
			local rate = rates[lineCombinationIndex]
			if not bestLineCombinationIndex or rate > bestRate then
				bestLineCombinationIndex = lineCombinationIndex
				bestRate = rate
			end
		end

		line.bestLineCombinationIndex = bestLineCombinationIndex
		line.bestLineCombination = self.lineCombinationsTable[line.reducedNoteCount][bestLineCombinationIndex]

		local time = assert(line.time)
		local columnNotes = self.lineCombinationsMap[line.reducedNoteCount][bestLineCombinationIndex]

		local lineExpDensities = self:lineExpDensities(time)
		for i = 1, self.targetMode do
			if columnNotes[i] == 1 then
				local stack = densityStacks[i]
				stack[#stack + 1] = {
					time,
					lineExpDensities[i]
				}
			end
		end
	end
end

---@param lines table
---@param columnCount number
---@param targetMode number
function LineBalancer:process(lines, columnCount, targetMode)
	self.lines = lines
	self.columnCount = columnCount
	self.targetMode = targetMode

	self:createLineCombinationsCountTable()
	self:createLineCombinationsTable()
	self:createLineCombinationsMap()

	--[[input
		reducedNoteCounts,
		lines
	]]

	-- print("balanceLines")
	self:balanceLines()

	--[[
		lineCombinations
	]]
end

return LineBalancer
