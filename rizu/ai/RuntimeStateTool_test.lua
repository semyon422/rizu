local json = require("web.json")
local JsonSchema = require("mcp.JsonSchema")
local RuntimeStateTool = require("rizu.ai.RuntimeStateTool")

local test = {}

---@param t testing.T
function test.reports_runtime_state(t)
	local select_screen = {}
	local chartview = {
		chartfile_id = 10,
		chartmeta_id = 20,
		title = "Title",
		artist = "Artist",
		name = "Hard",
		creator = "Mapper",
		hash = "hash",
		index = 1,
		inputmode = "4key",
		rate = 1.25,
	}
	local game = {
		ui = {
			current_screen = select_screen,
			screens = {select = select_screen},
		},
		chartSelector = {chartview = chartview},
		previewModel = {
			active = true,
			position = 12.5,
			mode = "absolute",
			rate = 1.25,
			audio_path = "audio.ogg",
		},
	}
	local tool = RuntimeStateTool(game --[[@as sphere.GameController]])
	local result = tool:execute({})

	t:eq(result.structured_content.screen, "select")
	t:eq(result.structured_content.selected_chart.title, "Title")
	t:eq(result.structured_content.preview.position, 12.5)
	t:tdeq(json.decode(result.content[1].text), result.structured_content)
	t:assert(JsonSchema.validate(tool.output_schema, result.structured_content))
end

---@param t testing.T
function test.reports_missing_selection(t)
	local game = {
		ui = {screens = {}},
		chartSelector = {},
		previewModel = {
			active = false,
			position = 0,
			mode = "absolute",
			rate = 1,
			audio_path = "",
		},
	}
	local tool = RuntimeStateTool(game --[[@as sphere.GameController]])
	local result = tool:execute({})

	t:eq(result.structured_content.screen, "unknown")
	t:eq(result.structured_content.selected_chart, nil)
	t:eq(result.structured_content.preview.audio_path, nil)
	t:assert(JsonSchema.validate(tool.output_schema, result.structured_content))
end

return test
