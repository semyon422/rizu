local PatternStrip = require("ui.screens.song_select_v2.PatternStrip")
local SphPreview = require("chart.format.sph.SphPreview")
local Fraction = require("chart.core.Fraction")

local test = {}

---A 4K stream of 16ths at 120 BPM, `beats` long.
---@param beats integer
---@return string
local function stream(beats)
	local lines = {{offset = 0, notes = {true}}}
	for beat = 1, beats do
		for k = 1, 3 do
			local notes = {}
			notes[k + 1] = true
			table.insert(lines, {time = Fraction(k, 4), notes = notes})
		end
		table.insert(lines, beat == beats and {offset = beats * 0.5, notes = {true}} or {notes = {true}})
	end
	return SphPreview:encode(lines, 1)
end

---@param strip ui.screens.song_select_v2.PatternStrip
---@return integer frames
local function finish(strip)
	local frames = 0
	repeat
		strip:update(1 / 60)
		frames = frames + 1
	until not strip.job or frames > 1000
	return frames
end

function test.analyzes_over_frames(t)
	local strip = PatternStrip()
	strip:bind({chartview = {hash = "a", index = 1, chartdiff_inputmode = "4key", notes_preview = stream(24)}})
	t:assert(strip.job)
	t:eq(strip.sections, nil)
	t:assert(finish(strip) >= 1)
	t:eq(#assert(strip.sections), 3)
	t:assert(strip.summary:find("^%S+ %d+%%"))
end

function test.skillsets_first_in_fixed_order(t)
	local strip = PatternStrip()
	strip:setSections({
		{time = 0, bpm = 180, nps = 10, labels = {jacks = 0.9, chordjack = 0.8, speed = 0.1}},
		{time = 5, bpm = 200, nps = 10, labels = {jacks = 0.7, jumpjack = 0.6}},
	})
	local labels, skillset = {}, {} ---@type string[], boolean[]
	for i, part in ipairs(strip.parts) do labels[i], skillset[i] = part.label, part.skillset end
	t:tdeq(labels, {"speed", "stamina", "jacks", "technical", "chordjack", "jumpjack"})
	t:tdeq(skillset, {true, true, true, true, false, false})
	t:eq(strip.parts[1].text, "speed 0%")
	t:eq(strip.parts[3].text, "jacks 100% 180 BPM")

	-- a section without a BPM, e.g. too few notes for one
	strip:setSections({{time = 0, nps = 1, labels = {speed = 0.9}}})
	t:eq(strip.parts[1].text, "speed 100%")
	t:eq(strip.parts[1].bpm, nil)
end

function test.unsupported_and_broken_charts(t)
	local strip = PatternStrip()
	strip:bind({chartview = {hash = "b", index = 1, chartdiff_inputmode = "5key", notes_preview = stream(24)}})
	finish(strip)
	t:eq(strip.sections, nil)
	t:eq(strip.summary, "")

	strip:bind({chartview = {hash = "c", index = 1, chartdiff_inputmode = "4key", notes_preview = "\1\2\3"}})
	finish(strip)
	t:eq(strip.sections, nil)
	t:assert(strip.summary:find("^patterns: "))
end

return test
