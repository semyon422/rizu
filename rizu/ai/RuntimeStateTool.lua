local class = require("class")
local json = require("web.json")

---@class rizu.ai.RuntimeScreenUi
---@field current_screen any?
---@field next_screen any?
---@field screens {[string]: any}?

---@class rizu.ai.RuntimeChartState
---@field chartfile_id integer?
---@field chartmeta_id integer?
---@field title string?
---@field artist string?
---@field name string?
---@field creator string?
---@field hash string?
---@field index integer?
---@field inputmode string?
---@field rate number?

---@class rizu.ai.RuntimePreviewState
---@field active boolean
---@field position number
---@field mode string
---@field rate number
---@field audio_path string?

---@class rizu.ai.RuntimeState
---@field screen string
---@field selected_chart rizu.ai.RuntimeChartState?
---@field preview rizu.ai.RuntimePreviewState

---@class rizu.ai.RuntimeStateTool
---@operator call: rizu.ai.RuntimeStateTool
---@field name string
---@field description string
---@field input_schema table
---@field output_schema table
---@field annotations mcp.ToolAnnotations
---@field game sphere.GameController
local RuntimeStateTool = class()

RuntimeStateTool.name = "get_runtime_state"
RuntimeStateTool.description = "Get the running game's current screen, selected chart, and preview state."
RuntimeStateTool.input_schema = {
	type = "object",
	properties = {},
	additionalProperties = false,
}
RuntimeStateTool.output_schema = {
	type = "object",
	properties = {
		screen = {type = "string"},
		selected_chart = {
			type = "object",
			properties = {
				chartfile_id = {type = "integer"},
				chartmeta_id = {type = "integer"},
				title = {type = "string"},
				artist = {type = "string"},
				name = {type = "string"},
				creator = {type = "string"},
				hash = {type = "string"},
				index = {type = "integer"},
				inputmode = {type = "string"},
				rate = {type = "number"},
			},
			additionalProperties = false,
		},
		preview = {
			type = "object",
			properties = {
				active = {type = "boolean"},
				position = {type = "number"},
				mode = {type = "string"},
				rate = {type = "number"},
				audio_path = {type = "string"},
			},
			required = {"active", "position", "mode", "rate"},
			additionalProperties = false,
		},
	},
	required = {"screen", "preview"},
	additionalProperties = false,
}
RuntimeStateTool.annotations = {
	readOnlyHint = true,
	destructiveHint = false,
	idempotentHint = true,
	openWorldHint = false,
}

---@param game sphere.GameController
function RuntimeStateTool:new(game)
	self.game = game
end

---@return string
function RuntimeStateTool:getScreenName()
	---@type rizu.ai.RuntimeScreenUi
	local ui = self.game.ui --[[@as rizu.ai.RuntimeScreenUi]]
	for name, screen in pairs(ui.screens or {}) do
		if screen == ui.current_screen then
			return name
		elseif screen == ui.next_screen then
			return "loading:" .. name
		end
	end
	return "unknown"
end

---@return rizu.ai.RuntimeChartState?
function RuntimeStateTool:getSelectedChart()
	local chartview = self.game.chartSelector.chartview
	if not chartview then
		return
	end
	return {
		chartfile_id = chartview.chartfile_id,
		chartmeta_id = chartview.chartmeta_id,
		title = chartview.title,
		artist = chartview.artist,
		name = chartview.name,
		creator = chartview.creator,
		hash = chartview.hash,
		index = chartview.index,
		inputmode = chartview.inputmode,
		rate = chartview.rate,
	}
end

---@param args {[string]: any}
---@return mcp.ToolResult
function RuntimeStateTool:execute(args)
	local preview = self.game.previewModel
	---@type rizu.ai.RuntimeState
	local state = {
		screen = self:getScreenName(),
		selected_chart = self:getSelectedChart(),
		preview = {
			active = preview.active == true,
			position = preview.position,
			mode = preview.mode,
			rate = preview.rate,
			audio_path = preview.audio_path ~= "" and preview.audio_path or nil,
		},
	}
	return {
		content = {{type = "text", text = json.encode(state)}},
		structured_content = state,
	}
end

return RuntimeStateTool
