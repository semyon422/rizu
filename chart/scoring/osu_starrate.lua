local class = require("class")

---@class omppc.Note
---@operator call: omppc.Note
local Note = class()

local INDIVIDUAL_DECAY_BASE = 0.125
local OVERALL_DECAY_BASE = 0.30

Note.overallStrain = 1

function Note:new(note, columns)
	self.startTime = note.time
	self.endTime = note.end_time or note.time
	self.key = note.column
	self.keymode = columns

	self.heldUntil = {}
	self.individualStrains = {}

	for i = 1, columns do
		self.individualStrains[i] = 0
		self.heldUntil[i] = 0
	end
end

function Note:getIndividualStrain()
	return self.individualStrains[self.key]
end

function Note:setIndividualStrain(value)
	self.individualStrains[self.key] = value
end

function Note:calculateStrains(pNote, timeRate)
	local addition = 1
	local timeElapsed = (self.startTime - pNote.startTime) / timeRate
	local individualDecay = math.pow(INDIVIDUAL_DECAY_BASE, timeElapsed)
	local overallDecay = math.pow(OVERALL_DECAY_BASE, timeElapsed)

	local holdFactor = 1
	local holdAddition = 0

	for i = 1, self.keymode do
		self.heldUntil[i] = pNote.heldUntil[i]

		if self.startTime < self.heldUntil[i] and self.endTime > self.heldUntil[i] then
			holdAddition = 1
		end
		if self.endTime == self.heldUntil[i] then
			holdAddition = 0
		end
		if self.heldUntil[i] > self.endTime then
			holdFactor = 1.25
		end
	end
	self.heldUntil[self.key] = self.endTime

	for i = 1, self.keymode do
		self.individualStrains[i] = pNote.individualStrains[i] * individualDecay
	end
	self:setIndividualStrain(self:getIndividualStrain() + 2 * holdFactor)

	self.overallStrain = pNote.overallStrain * overallDecay + (addition + holdAddition) * holdFactor
end

---@class ommpc.Beatmap
---@operator call: ommpc.Beatmap
local Beatmap = class()

function Beatmap:new(notes, columns, timeRate)
	local _notes = {}
	for i, note in ipairs(notes) do
		_notes[i] = Note(note, columns)
	end

	self.notes = _notes
	self.timeRate = timeRate
end

local STAR_SCALING_FACTOR = 0.018

function Beatmap:calculateStarRate()
	self:calculateStrainValues()
	self.starRate = self:calculateDifficulty() * STAR_SCALING_FACTOR
	return self.starRate
end

function Beatmap:calculateStrainValues()
	local cNote = self.notes[1]
	local nNote

	for i = 2, #self.notes do
		nNote = self.notes[i]
		nNote:calculateStrains(cNote, self.timeRate)
		cNote = nNote
	end
end

local STRAIN_STEP = 0.4
local DECAY_WEIGHT = 0.9

function Beatmap:calculateDifficulty()
	local actualStrainStep = STRAIN_STEP * self.timeRate

	local highestStrains = {}
	local intervalEndTime = actualStrainStep
	local maximumStrain = 0

	local pNote
	for i, note in ipairs(self.notes) do
		if note.startTime - intervalEndTime > 3600 then  -- note at inf protection
			break
		end
		while note.startTime > intervalEndTime do
			table.insert(highestStrains, maximumStrain)
			if not pNote then
				maximumStrain = 0
			else
				local individualDecay = math.pow(INDIVIDUAL_DECAY_BASE, intervalEndTime - pNote.startTime)
				local overallDecay = math.pow(OVERALL_DECAY_BASE, intervalEndTime - pNote.startTime)
				maximumStrain = pNote:getIndividualStrain() * individualDecay + pNote.overallStrain * overallDecay
			end

			intervalEndTime = intervalEndTime + actualStrainStep
		end

		local strain = note:getIndividualStrain() + note.overallStrain
		if strain > maximumStrain then
			maximumStrain = strain
		end

		pNote = note
	end

	local difficulty = 0
	local weight = 1
	table.sort(highestStrains, function(a, b) return a > b end)

	for _, strain in ipairs(highestStrains) do
		difficulty = difficulty + weight * strain
		weight = weight * DECAY_WEIGHT
	end

	return difficulty
end

return {
	Beatmap = Beatmap,
}
