local class = require("class")
local json = require("web.json")

---@class rizu.ai.NeedleTool
---@field name string
---@field description string
---@field routing_description string?
---@field parameters table
---@field argument_order string[]
---@field execute fun(arguments: {[string]: any})

---@class rizu.ai.NeedleToolSet
---@field tools rizu.ai.NeedleTool[]
---@field by_name {[string]: rizu.ai.NeedleTool}
---@field tools_json string
---@field routing_tools_json string

---@class rizu.ai.NeedleCall
---@field name string
---@field arguments {[string]: any}

---@class rizu.ai.NeedleToolRegistry
---@operator call: rizu.ai.NeedleToolRegistry
---@field registry rizu.command.Registry
local NeedleToolRegistry = class()

local function object(properties, required)
	local schema = {type = "object", properties = properties}
	if #required > 0 then schema.required = required end
	return schema
end

local function stringEnum(values, description)
	return {type = "string", enum = values, description = description}
end

---@param registry rizu.command.Registry
function NeedleToolRegistry:new(registry)
	self.registry = registry
end

---@return {[string]: rizu.command.Command}
function NeedleToolRegistry:getActiveCommands()
	local commands = {}
	for _, command in ipairs(self.registry:getActiveCommands()) do
		commands[command.id] = command
	end
	return commands
end

local function addTool(tools, by_name, tool)
	tools[#tools + 1] = tool
	by_name[tool.name] = tool
end

local function requiredSet(tool)
	local required = {}
	for _, key in ipairs(tool.parameters.required or {}) do required[key] = true end
	return required
end

local function encodeModelTools(tools)
	local encoded_tools = {}
	for _, tool in ipairs(tools) do
		local required = requiredSet(tool)
		local encoded_parameters = {}
		for _, key in ipairs(tool.argument_order) do
			local schema = tool.parameters.properties[key]
			local fields = {
				'"type":' .. json.encode(schema.type),
				'"description":' .. json.encode(schema.description),
				'"required":' .. tostring(required[key] == true),
			}
			if schema.enum then fields[#fields + 1] = '"enum":' .. json.encode(schema.enum) end
			encoded_parameters[#encoded_parameters + 1] = json.encode(key) .. ":{" .. table.concat(fields, ",") .. "}"
		end
		encoded_tools[#encoded_tools + 1] = ("{\"name\":%s,\"description\":%s,\"parameters\":{%s}}")
			:format(json.encode(tool.name), json.encode(tool.description), table.concat(encoded_parameters, ","))
	end
	return "[" .. table.concat(encoded_tools, ",") .. "]"
end

local function encodeRoutingTools(tools)
	local encoded_tools = {}
	for _, tool in ipairs(tools) do
		encoded_tools[#encoded_tools + 1] = ("{\"name\":%s,\"description\":%s}")
			:format(json.encode(tool.name), json.encode(tool.routing_description or tool.description))
	end
	return "[" .. table.concat(encoded_tools, ",") .. "]"
end

---@return rizu.ai.NeedleToolSet
function NeedleToolRegistry:snapshot()
	local commands = self:getActiveCommands()
	---@type rizu.ai.NeedleTool[]
	local tools = {}
	---@type {[string]: rizu.ai.NeedleTool}
	local by_name = {}

	local rate = commands["global.rate"]
	if rate then
		addTool(tools, by_name, {
			name = "set_playback_rate",
			description = "Set the music playback rate.",
			routing_description = "rate speed playback music",
			parameters = object({rate = {type = "number", description = "Playback rate multiplier."}}, {"rate"}),
			argument_order = {"rate"},
			execute = function(args)
				local validate = rate.arguments and rate.arguments[1].validate
				if validate then
					local valid, err = validate(tostring(args.rate))
					assert(valid, err)
				end
				rate.callback(args)
			end,
		})
	end

	local screenshot = commands["global.screenshot"]
	local screenshot_open = commands["global.screenshot_open"]
	if screenshot and screenshot_open then
		addTool(tools, by_name, {
			name = "capture_screenshot",
			description = "Capture a screenshot, optionally opening it in the file manager.",
			routing_description = "screenshot capture image",
			parameters = object({mode = stringEnum({"save", "save_and_open"}, "Whether to save only or save and open the screenshot.")}, {"mode"}),
			argument_order = {"mode"},
			execute = function(args)
				(args.mode == "save_and_open" and screenshot_open or screenshot).callback({})
			end,
		})
	end

	local set_search = commands["select.set_search"]
	if set_search then
		addTool(tools, by_name, {
			name = "set_chart_search",
			description = "Set the chart search query. Use an empty query to clear it.",
			routing_description = "search filter charts songs",
			parameters = object({query = {type = "string", description = "Chart search text, or an empty string to clear search."}}, {"query"}),
			argument_order = {"query"},
			execute = function(args) set_search.callback(args) end,
		})
	end

	local random_chart = commands["select.random_chart"]
	if random_chart then
		addTool(tools, by_name, {
			name = "select_random_chart",
			description = "Select a random chart.",
			routing_description = "random chart song select",
			parameters = object({}, {}),
			argument_order = {},
			execute = function() random_chart.callback({}) end,
		})
	end

	local play = commands["ui.select.play"]
	local autoplay = commands["ui.select.autoplay"]
	if play and autoplay then
		addTool(tools, by_name, {
			name = "start_selected_chart",
			description = "Start the selected chart normally or with autoplay.",
			routing_description = "play start chart autoplay",
			parameters = object({mode = stringEnum({"play", "autoplay"}, "How to start the selected chart.")}, {"mode"}),
			argument_order = {"mode"},
			execute = function(args) (args.mode == "autoplay" and autoplay or play).callback({}) end,
		})
	end

	local column_commands = {
		reset = commands["play_config.columns_reset"],
		mirror = commands["play_config.columns_mirror"],
		bracketswap = commands["play_config.columns_bracketswap"],
		random_all = commands["play_config.columns_random"],
		random_left = commands["play_config.columns_random"],
		random_right = commands["play_config.columns_random"],
	}
	if column_commands.reset and column_commands.mirror and column_commands.bracketswap and column_commands.random_all then
		addTool(tools, by_name, {
			name = "set_column_layout",
			description = "Change the gameplay column layout.",
			routing_description = "columns layout mirror random",
			parameters = object({layout = stringEnum({"reset", "mirror", "bracketswap", "random_all", "random_left", "random_right"}, "Column layout operation to apply.")}, {"layout"}),
			argument_order = {"layout"},
			execute = function(args)
				local command = assert(column_commands[args.layout])
				local mode = ({random_left = "left", random_right = "right", random_all = ""})[args.layout]
				command.callback(mode and {mode = mode} or {})
			end,
		})
	end

	local option_commands = {
		auto_timings = commands["play_config.set_auto_timings"],
		nearest = commands["play_config.set_nearest"],
		tap_only = commands["play_config.set_tap_only"],
		const = commands["play_config.set_const"],
		custom = commands["play_config.set_custom"],
	}
	if option_commands.auto_timings and option_commands.nearest and option_commands.tap_only and option_commands.const and option_commands.custom then
		addTool(tools, by_name, {
			name = "set_play_option",
			description = "Enable or disable a gameplay option.",
			routing_description = "gameplay option enable disable",
			parameters = object({
				option = stringEnum({"auto_timings", "nearest", "tap_only", "const", "custom"}, "Play option to change."),
				enabled = {type = "boolean", description = "Whether the option should be enabled."},
			}, {"option", "enabled"}),
			argument_order = {"option", "enabled"},
			execute = function(args) assert(option_commands[args.option]).callback({enabled = args.enabled}) end,
		})
	end

	local panel_commands = {
		modifiers = commands["ui.select.open_modifiers"], filters = commands["ui.select.open_filters"],
		input = commands["ui.select.open_input"], note_skins = commands["ui.select.open_noteskins"],
		editor = commands["ui.global.open_editor"],
	}
	if panel_commands.modifiers then
		addTool(tools, by_name, {
			name = "open_panel",
			description = "Open a game configuration panel or the chart editor.",
			routing_description = "open settings panel editor",
			parameters = object({panel = stringEnum({"modifiers", "filters", "input", "note_skins", "editor"}, "Panel to open.")}, {"panel"}),
			argument_order = {"panel"},
			execute = function(args) assert(panel_commands[args.panel]).callback({}) end,
		})
	end

	local gameplay_commands = {
		pause = commands["gameplay.pause"], resume = commands["gameplay.resume"],
		retry = commands["gameplay.retry"], skip_intro = commands["gameplay.skip_intro"],
	}
	if gameplay_commands.pause then
		addTool(tools, by_name, {
			name = "control_gameplay",
			description = "Pause, resume, retry, or skip the intro of gameplay.",
			routing_description = "pause resume retry gameplay",
			parameters = object({action = stringEnum({"pause", "resume", "retry", "skip_intro"}, "Gameplay action to perform.")}, {"action"}),
			argument_order = {"action"},
			execute = function(args) assert(gameplay_commands[args.action]).callback({}) end,
		})
	end

	local offset_commands = {
		decrease = commands["gameplay.offset_decrease"], increase = commands["gameplay.offset_increase"],
		reset = commands["gameplay.offset_reset"],
	}
	if offset_commands.decrease then
		addTool(tools, by_name, {
			name = "adjust_local_offset",
			description = "Decrease, increase, or reset the selected chart local offset.",
			routing_description = "offset decrease increase reset",
			parameters = object({action = stringEnum({"decrease", "increase", "reset"}, "Local offset adjustment to perform.")}, {"action"}),
			argument_order = {"action"},
			execute = function(args) assert(offset_commands[args.action]).callback({}) end,
		})
	end

	return {
		tools = tools,
		by_name = by_name,
		tools_json = encodeModelTools(tools),
		routing_tools_json = encodeRoutingTools(tools),
	}
end

local function validateArguments(tool, arguments)
	if type(arguments) ~= "table" then return nil, "arguments must be an object" end
	local properties = tool.parameters.properties
	for key in pairs(arguments) do
		if properties[key] == nil then return nil, "unexpected argument: " .. tostring(key) end
	end
	for _, key in ipairs(tool.parameters.required or {}) do
		if arguments[key] == nil then return nil, "missing argument: " .. key end
	end
	for key, schema in pairs(properties) do
		local value = arguments[key]
		if value ~= nil then
			if type(value) ~= schema.type then return nil, ("argument %s must be %s"):format(key, schema.type) end
			if schema.type == "number" and (value ~= value or value == math.huge or value == -math.huge) then
				return nil, "argument " .. key .. " must be finite"
			end
			if schema.enum then
				local found = false
				for _, allowed in ipairs(schema.enum) do found = found or value == allowed end
				if not found then return nil, "invalid value for argument: " .. key end
			end
		end
	end
	return true
end

---@param tool_set rizu.ai.NeedleToolSet
---@param text string
---@return rizu.ai.NeedleCall? call
---@return string? error_message
function NeedleToolRegistry.parse(tool_set, text)
	local decoded, err = json.decode_safe(text)
	if not decoded then return nil, "invalid tool-call JSON: " .. tostring(err) end
	if type(decoded) ~= "table" or #decoded ~= 1 or next(decoded, 1) ~= nil then
		return nil, "Needle must produce exactly one tool call"
	end
	local call = decoded[1]
	if type(call) ~= "table" or type(call.name) ~= "string" then return nil, "tool call has no name" end
	for key in pairs(call) do
		if key ~= "name" and key ~= "arguments" then return nil, "unexpected tool-call field: " .. tostring(key) end
	end
	local tool = tool_set.by_name[call.name]
	if not tool then return nil, "unknown tool: " .. call.name end
	local valid, validation_error = validateArguments(tool, call.arguments)
	if not valid then return nil, validation_error end
	return {name = call.name, arguments = call.arguments}
end

---@param tool_set rizu.ai.NeedleToolSet
---@param call rizu.ai.NeedleCall
function NeedleToolRegistry.execute(tool_set, call)
	assert(tool_set.by_name[call.name]).execute(call.arguments)
end

---@param tool_set rizu.ai.NeedleToolSet
---@param call rizu.ai.NeedleCall
---@return string
function NeedleToolRegistry.format(tool_set, call)
	local tool = assert(tool_set.by_name[call.name])
	local parts = {}
	for _, key in ipairs(tool.argument_order) do
		parts[#parts + 1] = key .. " = " .. json.encode(call.arguments[key])
	end
	return call.name .. "(" .. table.concat(parts, ", ") .. ")"
end

return NeedleToolRegistry
