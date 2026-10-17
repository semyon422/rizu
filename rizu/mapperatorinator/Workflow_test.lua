local FakeFilesystem = require("fs.FakeFilesystem")
local MapperatorinatorConfig = require("rizu.mapperatorinator.Config")
local Workflow = require("rizu.mapperatorinator.Workflow")

local test = {}

local function makeWorkflow()
	local fs = FakeFilesystem()
	fs:setWorkingDirectory("/game")
	fs:createDirectory("userdata/charts/mapperatorinator")
	local host_fs = FakeFilesystem()
	host_fs:createDirectory("home/test/code/Mapperatorinator/.venv/bin")
	host_fs:createDirectory("music")
	host_fs:createDirectory("maps")
	host_fs:write("home/test/code/Mapperatorinator/inference.py", "")
	host_fs:write("home/test/code/Mapperatorinator/.venv/bin/python", "")
	host_fs:write("music/song.ogg", "audio")
	host_fs:write("maps/reference.osu", "osu file format v14")
	local request
	local transport = {
		start = function(_, value) request = value end,
		pop = function() end,
		isRunning = function() return true end,
	}
	local library_path
	local game = {
		fs = fs,
		library = {
			computeLocation = function(_, path) library_path = path end,
		},
	}
	local ui = {}
	local workflow = Workflow(game, ui, transport, host_fs) ---@diagnostic disable-line
	local config = MapperatorinatorConfig.create(fs, "/home/test")
	return workflow, config, fs, host_fs, function() return request, library_path end
end

---@param t testing.T
function test.starts_generation_and_copies_audio(t)
	local workflow, config, fs, _, getValues = makeWorkflow()
	local old_time = os.time
	os.time = function() return 123 end
	local old_os = jit.os
	jit.os = "Linux"
	local ok, err = workflow:start("music/song.ogg", config)
	jit.os = old_os
	os.time = old_time
	t:eq(ok, true)
	t:eq(err, nil)
	t:eq(workflow.state, "generating")
	t:eq(fs:read("userdata/charts/mapperatorinator/123/audio.ogg"), "audio")
	local request = getValues()
	t:eq(request.output_path, "/game/userdata/charts/mapperatorinator/123")
	t:eq(request.gamemode, 3)
	t:eq(request.model, "v32")
	t:eq(request.precision, "bf16")
	t:eq(request.difficulty, 5)
	t:eq(request.keycount, 4)
end

---@param t testing.T
function test.validates_runtime_paths(t)
	local workflow, config, _, host_fs = makeWorkflow()
	host_fs:remove("home/test/code/Mapperatorinator/inference.py")
	local old_os = jit.os
	jit.os = "Linux"
	local ok, err = workflow:start("music/song.ogg", config)
	jit.os = old_os
	t:eq(ok, false)
	t:assert(err:find("inference.py", 1, true))
end

---@param t testing.T
function test.serializes_reference_and_advanced_options(t)
	local workflow, config, fs, _, getValues = makeWorkflow()
	local keys = MapperatorinatorConfig.keys
	config:setString(keys.reference_path, "maps/reference.osu")
	config:setString(keys.descriptors, "skillset/tech, style/geometric\nskillset/tech")
	config:setString(keys.negative_descriptors, "general/gimmick")
	config:setString(keys.mapper_id, "42")
	config:setString(keys.start_time, "1000")
	config:setString(keys.end_time, "2000")
	config:setBoolean(keys.context_timing, true)
	config:setBoolean(keys.add_to_beatmap, true)
	local old_time = os.time
	os.time = function() return 321 end
	local old_os = jit.os
	jit.os = "Linux"
	local ok, err = workflow:start("music/song.ogg", config)
	jit.os = old_os
	os.time = old_time
	t:eq(ok, true)
	t:eq(err, nil)
	t:eq(fs:read("userdata/charts/mapperatorinator/321/reference.osu"), "osu file format v14")
	local request = getValues()
	t:eq(request.beatmap_path, "/game/userdata/charts/mapperatorinator/321/reference.osu")
	t:eq(request.mapper_id, 42)
	t:eq(request.start_time, 1000)
	t:eq(request.end_time, 2000)
	t:eq(request.add_to_beatmap, true)
	t:eq(request.in_context[1], "TIMING")
	t:eq(#request.descriptors, 2)
	t:eq(request.negative_descriptors[1], "general/gimmick")
end

---@param t testing.T
function test.validates_optional_numbers(t)
	local workflow, config = makeWorkflow()
	config:setString(MapperatorinatorConfig.keys.seed, "not a number")
	local old_os = jit.os
	jit.os = "Linux"
	local ok, err = workflow:start("music/song.ogg", config)
	jit.os = old_os
	t:eq(ok, false)
	t:assert(err:find("Seed", 1, true))
end

---@param t testing.T
function test.validates_model_year(t)
	local workflow, config = makeWorkflow()
	config:setChoice(MapperatorinatorConfig.keys.model, "v31")
	local old_os = jit.os
	jit.os = "Linux"
	local ok, err = workflow:start("music/song.ogg", config)
	jit.os = old_os
	t:eq(ok, false)
	t:assert(err:find("2023", 1, true))
end

---@param t testing.T
function test.queues_generated_chart_for_cache(t)
	local workflow, config, fs, _, getValues = makeWorkflow()
	local old_time = os.time
	os.time = function() return 456 end
	local old_os = jit.os
	jit.os = "Linux"
	t:eq(workflow:start("music/song.ogg", config), true)
	jit.os = old_os
	os.time = old_time
	fs:write("userdata/charts/mapperatorinator/456/beatmap.osu", "osu chart")
	workflow:finishGeneration()
	local _, library_path = getValues()
	t:eq(workflow.state, "caching")
	t:eq(library_path, "mapperatorinator/456")
	t:eq(type(workflow.generated_hash), "string")
	t:eq(#workflow.generated_hash, 32)
end

return test
