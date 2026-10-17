local GenerationRunner = require("rizu.mapperatorinator.GenerationRunner")

local test = {}

local request = {
	repository_path = "/tmp/Mapper ator's",
	python_path = "/tmp/venv's/python",
	audio_path = "/music/it's fine.ogg",
	output_path = "/charts/output dir",
	model = "v32",
	gamemode = 3,
	difficulty = 6.2,
	keycount = 7,
	year = 2024,
	title = "Artist's chart, [test]",
	descriptors = {"skillset/tech", "style/geometric"},
	in_context = {"TIMING", "NO_HS"},
	hitsounded = true,
}

---@param t testing.T
function test.builds_quoted_hydra_command(t)
	local runner = GenerationRunner()
	local command = runner:buildCommand(request)
	t:assert(command:find("cd '/tmp/Mapper ator'\\''s'", 1, true))
	t:assert(command:find("'/tmp/venv'\\''s/python' inference.py", 1, true))
	t:assert(command:find("--config-name 'v32'", 1, true))
	t:assert(command:find("'audio_path=\"/music/it'\\''s fine.ogg\"'", 1, true))
	t:assert(command:find("'output_path=\"/charts/output dir\"'", 1, true))
	t:assert(command:find("'gamemode=3' 'difficulty=6.2' 'year=2024'", 1, true))
	t:assert(command:find("'descriptors=[\"skillset/tech\",\"style/geometric\"]'", 1, true))
	t:assert(command:find("'in_context=[\"TIMING\",\"NO_HS\"]'", 1, true))
	t:assert(command:find("'title=\"Artist'\\''s chart, [test]\"'", 1, true))
	t:assert(command:find("'hitsounded=true'", 1, true))
	t:assert(command:find("hydra.output_subdir=null", 1, true))
end

---@param t testing.T
function test.reports_execution_result(t)
	local executed
	local runner = GenerationRunner(function(command)
		executed = command
		return 0
	end)
	local ok, err = runner:run(request)
	t:eq(ok, true)
	t:eq(err, nil)
	t:eq(executed, runner:buildCommand(request))

	runner = GenerationRunner(function() return 512 end)
	ok, err = runner:run(request)
	t:eq(ok, false)
	t:assert(err:find("exited with 2", 1, true))
end

return test
