local GlobalCommands = require("yi.command_palette.GlobalCommands")

local test = {}

---@param t testing.T
function test.opens_ai_chat(t)
	local opened = false
	local ui = {
		overlay = {
			attachChat = function()
				opened = true
			end,
		},
	}
	local command
	for _, candidate in ipairs(GlobalCommands.get({}, ui)) do
		if candidate.id == "global.ai_chat" then
			command = candidate
			break
		end
	end
	t:assert(command, "AI chat command should be registered")
	command.callback({})
	t:eq(opened, true)
end

---@param t testing.T
function test.registers_needle_live_argument(t)
	local command
	for _, candidate in ipairs(GlobalCommands.get({}, nil)) do
		if candidate.id == "global.needle" then command = candidate end
	end
	t:assert(command, "Needle command should be registered")
	t:eq(command.arguments[1].name, "query")
	t:eq(command.arguments[1].type, "string")
end

---@param t testing.T
function test.starts_needle_gpu_probe(t)
	local started = false
	local command
	for _, candidate in ipairs(GlobalCommands.get({needleGpuProbe = {start = function() started = true end}}, nil)) do
		if candidate.id == "global.needle_gpu_probe" then command = candidate end
	end
	t:assert(command, "Needle GPU probe command should be registered")
	command.callback({})
	t:eq(started, true)
end

---@param t testing.T
function test.starts_needle_gpu_encoder_probe(t)
	local started_path
	local game = {
		needleGpuEncoderProbe = {start = function(_, path) started_path = path end},
		persistence = {configModel = {configs = {needle = {model_path = "model.bin"}}}},
	}
	local command
	for _, candidate in ipairs(GlobalCommands.get(game, nil)) do
		if candidate.id == "global.needle_gpu_encoder_probe" then command = candidate end
	end
	t:assert(command, "Needle GPU encoder probe command should be registered")
	command.callback()
	t:eq(started_path, "model.bin")
end

---@param t testing.T
function test.starts_needle_gpu_prefill_probe(t)
	local started_path
	local game = {
		needleGpuEncoderProbe = {startPrefill = function(_, path) started_path = path end},
		persistence = {configModel = {configs = {needle = {model_path = "model.bin"}}}},
	}
	local command
	for _, candidate in ipairs(GlobalCommands.get(game, nil)) do
		if candidate.id == "global.needle_gpu_prefill_probe" then command = candidate end
	end
	t:assert(command, "Needle GPU prefill probe command should be registered")
	command.callback()
	t:eq(started_path, "model.bin")
end

return test
