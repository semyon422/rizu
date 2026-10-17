local VideoExport = require("ui.modals.video_export.VideoExport")

local test = {}

---@param preview_time number?
---@param first number
---@param last number
---@return number start
---@return number length
local function range(preview_time, first, last)
	local modal = setmetatable({api = {
		media = {getPreviewTime = function() return 0, first, last end},
		charts = {getSelectedChart = function() return {preview_time = preview_time} end},
	}}, {__index = VideoExport})
	return modal:getRange()
end

---@param t testing.T
function test.starts_at_the_chartview_preview_position(t)
	t:tdeq({range(42.5, 0, 120)}, {42.5, 77.5})
end

---@param t testing.T
function test.falls_back_to_the_audio_start_without_a_preview_position(t)
	t:tdeq({range(nil, 3, 100)}, {3, 97})
	t:tdeq({range(0, 3, 100)}, {3, 97})
end

---@param t testing.T
function test.moves_back_when_too_little_audio_follows(t)
	t:tdeq({range(118, 0, 120)}, {115, 5})
	t:tdeq({range(500, 0, 120)}, {115, 5})
end

return test
