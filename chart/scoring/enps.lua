-- extended notes per second

local enps = {}

local test = false

--[[
	expDensity = f(deltaTime, previousDensity)

	Properties:
		f(0, c) = c + 1
		f(inf, c) = 0
		f(1 / c, c) = c

	Derivation:
		f(t, c) = (c + 1) * math.exp(-a * t)
		f(1 / c, c) = (c + 1) * math.exp(-a / c)
		(c + 1) * math.exp(-a / c) = c
		math.exp(-a / c) = c / (c + 1)
		-a / c = math.log(c / (c + 1))
		-a = c * math.log(c / (c + 1))
		-a = -c * math.log((c + 1) / c)
		f(t, c) = (c + 1) * math.exp(-c * math.log((c + 1) / c) * deltaTime)
		f(t, c) = (c + 1) * (1 / c + 1) ^ (-c * t)

		f(t, 0) = (c + 1) * (1 / c + 1) ^ (-c * t)
				= (1 / c + 1) ^ (c / c * c * (-t))
				= (1 / c + 1) ^ (c * (-t))
				= math.exp(-t)

	Usage:
		make first notes on each input have density == 0
		compute density for other notes:
			note2.density = expDensity(
				note2.time - note1.time,
				note1.density
			)
		where note1.input == note2.input
]]

---@param t number
---@param c number
---@return number
function enps.expDensity(t, c)
	return c == 0 and math.exp(-t) or (c + 1) / (1 / c + 1) ^ (c * t)
end

---@param notes any
---@return number
---@return table
function enps.noteStrain(notes)
	local lastNotes = {}
	local strains = {}
	local sumStrain = 0

	if #notes == 0 then
		return 0, strains
	end

	for _, note in ipairs(notes) do
		if lastNotes[note.input] then
			note.lastNote = lastNotes[note.input]
			note.strain = enps.expDensity(note.time - note.lastNote.time, note.lastNote.strain)
		else
			note.strain = note.strain or 0
		end
		lastNotes[note.input] = note
		sumStrain = sumStrain + note.strain
		strains[#strains + 1] = note.strain
	end
	table.sort(strains, function(a, b) return a > b end)

	return sumStrain / #notes, strains
end

---@param notes table
---@return number
function enps.generalizedKeymode(notes)
	if #notes == 0 then
		return 0
	end

	local dict = {}

	for _, note in ipairs(notes) do
		dict[note.input] = (dict[note.input] or 0) + 1
	end

	local list = {}
	for _, count in pairs(dict) do
		list[#list + 1] = count
	end
	table.sort(list)

	local sum = 0
	local weight = 0
	local offset = 0

	for i = 1, #list do
		sum = sum + (#list - i + 1) * (list[i] - offset)
		weight = weight + list[i] - offset
		offset = list[i]
	end

	return sum / weight
end

---@param notes table
---@return number
---@return number
---@return number
---@return table
function enps.getEnps(notes)
	local aStrain, strains = enps.noteStrain(notes)
	local generalizedKeymode = enps.generalizedKeymode(notes)

	return aStrain * generalizedKeymode, aStrain, generalizedKeymode, strains
end

if test then
	assert(enps.expDensity(0, 100) == 101)
	assert(enps.expDensity(math.huge, 100) == 0)

	local notes = {
		{time = 0,		input = 1, density = 1},
		{time = 0.5,	input = 2, density = 1},
		{time = 1,		input = 1},
		{time = 1.5,	input = 2}
	}
	local inputs = 2
	local anps = 2

	notes[3].density = enps.expDensity(
		(notes[3].time - notes[1].time) / inputs * anps,
		notes[1].density
	)
	notes[4].density = enps.expDensity(
		(notes[4].time - notes[2].time) / inputs * anps,
		notes[2].density
	)
	assert(math.abs(notes[3].density - notes[1].density) < 0.001)
	assert(math.abs(notes[4].density - notes[2].density) < 0.001)
end

if test then
	local notes = {
		{time = 0, input = 1, density = 1},
		{time = 0, input = 2, density = 1},
		{time = 0, input = 3, density = 1},
		{time = 0, input = 4, density = 1},
		{time = 2, input = 1},
		{time = 2, input = 2},
		{time = 2, input = 3},
		{time = 2, input = 4}
	}
	local inputs = 4
	local anps = 2

	notes[5].density = enps.expDensity(
		(notes[5].time - notes[1].time) / inputs * anps,
		notes[1].density
	)
	assert(math.abs(notes[5].density - notes[1].density) < 0.001)
end

if test then
	local notes = {}
	for t = 1, 75, 1 do
		table.insert(notes, {
			time = t,
			input = 1
		})
	end
	for t = 1, 25, 1 do
		table.insert(notes, {
			time = t,
			input = 2
		})
	end
	assert(math.abs(enps.generalizedKeymode(notes) - 1.33) < 0.05)
end

if test then
	local notes = {}
	for t = 0, 1000, 1 do
		table.insert(notes, {
			time = t,
			input = 1
		})
	end
	for t = 2000, 3000, 1 do
		table.insert(notes, {
			time = t,
			input = 1
		})
	end
	assert(math.abs(enps.getEnps(notes) - 1) < 0.05)
end

if test then
	local notes = {}
	for t = 0, 1000, 1 do
		table.insert(notes, {
			time = t,
			input = 1
		})
	end
	for t = 0.1, 1000, 1 do
		table.insert(notes, {
			time = t,
			input = 1
		})
	end
	table.sort(notes, function(a, b) return a.time < b.time end)
	assert(math.abs(enps.getEnps(notes) - 2) < 0.05)
end

if test then
	local notes = {}
	for t = 0, 1000, 1 do
		table.insert(notes, {
			time = t,
			input = 1
		})
	end
	for t = 0.1, 1000, 1 do
		table.insert(notes, {
			time = t,
			input = 2
		})
	end
	table.sort(notes, function(a, b) return a.time < b.time end)
	assert(math.abs(enps.getEnps(notes) - 2) < 0.05)
end

return enps
