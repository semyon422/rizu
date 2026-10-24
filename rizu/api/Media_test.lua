local Media = require("rizu.api.Media")

local test = {}

---@param t testing.T
function test.background_and_preview(t)
	local background_listener
	local background = {
		onChanged = function(_, f) background_listener = f end,
	}
	local seeks = {}
	local preview = {
		chartPreview = {notes = {timing_vertices = {}, getBeatAtTime = function(_, time) return time * 2 end}},
		getRange = function() return 1, 9 end,
		getTime = function() return 4 end,
		setRelativePosition = function(_, p) seeks[#seeks + 1] = p end,
		setPosition = function(_, time) seeks[#seeks + 1] = time end,
	}
	local media = Media(background --[[@as any]], preview --[[@as any]])

	local images, alpha = media:getBackgroundImages()
	t:eq(#images, 0)
	t:eq(alpha, 0)
	local again = media:getBackgroundImages()
	t:eq(again, images, "the empty answer is shared")

	local received
	media:on("background_changed", function(image) received = image end)
	background_listener({image = "img"})
	t:eq(received, "img")

	t:tdeq({media:getPreviewTime()}, {4, 1, 9})
	t:eq(media:getBeat(), 8)
	media:seekPreview(0.5)
	media:setPreviewTime(3)
	t:tdeq(seeks, {0.5, 3})

	preview.chartPreview.notes = nil
	t:eq(media:getBeat(), nil)
end

---@param t testing.T
function test.start_and_stop_preview(t)
	local preview = {active = false, stop = function(self) self.active = false end}
	local selection = {startPreview = function() preview.active = true end}
	local media = Media({onChanged = function() end} --[[@as any]], preview --[[@as any]], selection --[[@as any]])
	t:eq(media:isPreviewActive(), false)
	media:startPreview()
	t:eq(media:isPreviewActive(), true)
	media:stopPreview()
	t:eq(media:isPreviewActive(), false)
end

---@param t testing.T
function test.draw_notes_preview_at_another_time(t)
	local drawn = {}
	local preview = {
		chartPreview = {time = 1, rate = 2},
		getPlayfield = function()
			return {drawPreview = function(_, player, w, h) drawn[#drawn + 1] = {player.time, player.rate, w, h} end}
		end,
	}
	local media = Media({onChanged = function() end} --[[@as any]], preview --[[@as any]])
	media:drawNotesPreview(10, 20)
	t:tdeq(drawn, {{1, 2, 10, 20}})
end

return test
