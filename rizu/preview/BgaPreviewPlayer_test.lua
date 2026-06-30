local BgaPreviewPlayer = require("rizu.preview.BgaPreviewPlayer")

local test = {}

---@param player rizu.preview.BgaPreviewPlayer
local function disableVideoEngineUpdate(player)
	function player.video_engine:update() end
end

---@param t testing.T
function test.update_drives_each_video_name_once(t)
	local player = BgaPreviewPlayer()
	disableVideoEngineUpdate(player)
	player.preview = {
		samples = {
			"shared.mp4",
			"background.png",
		},
	}
	player.events_by_column = {
		[1] = {
			{time = 0, sample_index = 1, column = 1},
		},
		[2] = {
			{time = 2, sample_index = 1, column = 2},
		},
		[3] = {
			{time = 1, sample_index = 2, column = 3},
		},
	}

	player:update(3)

	t:eq(#player.active_notes, 2)
	t:eq(player.active_notes[1].type, "VideoNote")
	t:eq(player.active_notes[1].name, "shared.mp4")
	t:eq(player.active_notes[1].time, 2)
	t:eq(player.active_notes[1].column, 2)
	t:eq(player.active_notes[2].type, "ImageNote")
	t:eq(player.active_notes[2].name, "background.png")
end

return test
