---@class chart.bms.TestFixtures
local TestFixtures = {}

---@param lines string[]
---@return string
function TestFixtures.join(lines)
	return table.concat(lines, "\n") .. "\n"
end

---@param body string[]?
---@return string
function TestFixtures.basic(body)
	local lines = {
		"#TITLE Fixture Song [Normal]",
		"#ARTIST Fixture Artist",
		"#PLAYLEVEL 5",
		"#RANK 3",
		"#STAGEFILE stage.png",
		"#BPM 120",
		"#WAV01 hit.wav",
		"#WAV02 bgm.wav",
		"#BMP01 image.png",
		"#BPM01 180",
		"#STOP01 48",
	}
	for _, line in ipairs(body or {}) do
		lines[#lines + 1] = line
	end
	return TestFixtures.join(lines)
end

---@param channels string[]
---@return string
function TestFixtures.mode(channels)
	local lines = {
		"#TITLE Mode",
		"#ARTIST Tester",
		"#BPM 130",
	}
	for _, channel in ipairs(channels) do
		lines[#lines + 1] = ("#001%s:01"):format(channel)
	end
	return TestFixtures.join(lines)
end

return TestFixtures
