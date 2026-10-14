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

return test
