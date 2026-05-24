local class = require("class")
local MidiLua = require("MIDI")

---@class chart.midi.MID
---@operator call: chart.midi.MID
local MID = class()

---@param midString string
function MID:new(midString)
    local opus = MidiLua.midi2opus(midString)

    local ticks = opus[1]
    local notes = {}
    local tempos = {}
    local notesIndex = 1
    local dt
    local noteType
    for i = 2, #opus do
        dt = 0
        for _, event in ipairs(opus[i]) do
            dt = dt + event[2]

            if event[1] == "note_on" or event[1] == "note_off" then
                notes[notesIndex] = notes[notesIndex] or {}
                noteType = (event[1] == "note_on" and event[5] ~= 0) and true or false

                notes[notesIndex][#notes[notesIndex]+1] = {
                    noteType,
                    (dt / ticks) / 4,
                    event[4] - 20,
                    event[5] / 127
                }
            elseif event[1] == "set_tempo" then
                tempos[#tempos+1] = {
                    (dt / ticks) / 4,
                    math.floor((60000000 / event[3]) + 0.5)
                }
            end
        end

        if notes[notesIndex] then
            notesIndex = notesIndex + 1
        end
    end

    if not tempos[1] or tempos[1][1] ~= 0 then
        table.insert(tempos, 1, { 0, 120 })
    end

    local minTime = 100000
    local maxTime = 0
    for _, track in ipairs(notes) do
        if track[1][2] < minTime then minTime = track[1][2] end
        if track[#track][2] > maxTime then maxTime = track[#track][2] end
    end
    minTime = math.floor(60 / (tempos[1][2] / (minTime * 4)))
    maxTime = math.ceil(60 / (tempos[#tempos][2] / (maxTime * 4)))

    self.notes = notes
    self.tempos = tempos
    self.bpm = tempos[1][2]
    self.minTime = minTime
    self.maxTime = maxTime
    self.length = maxTime - minTime
end

return MID
