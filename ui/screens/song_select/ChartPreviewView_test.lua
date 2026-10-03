local ChartPreviewView = require("ui.screens.song_select.ChartPreviewView")
local test = {}

---@param t testing.T
function test.view_bind_and_unload_do_not_own_core_resources(t)
	local release_count = 0
	local view = setmetatable({game = {previewModel = {
		release = function() error("UI must not release the game preview") end,
	}}, preview_canvas = {release = function() release_count = release_count + 1 end}},
		{__index = ChartPreviewView})
	view:bind({chartview = {chartdiff_inputmode = "14key", chartmeta_mode = "mania"}})
	view:unload()
	view:unload()
	t:eq(release_count, 1)
	t:eq(view.preview_canvas, nil)
	t:eq(view.preview_renderer_cache, nil)
end

return test
