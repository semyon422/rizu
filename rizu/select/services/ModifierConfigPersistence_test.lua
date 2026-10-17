local ModifierConfigPersistence = require("rizu.select.services.ModifierConfigPersistence")

local test = {}

---@param calls string[]
local function createConfigModel(calls)
	return {
		configs = {
			play = {
				rate = 1.5,
			},
		},
		write = function()
			table.insert(calls, "write")
		end,
	}
end

---@param t testing.T
function test.load_replay_base_writes_and_imports_play_config(t)
	local calls = {}
	local replayBase = {
		importReplayBase = function(_, play_config)
			table.insert(calls, "import:" .. tostring(play_config.rate))
		end,
	}

	ModifierConfigPersistence(createConfigModel(calls)):loadReplayBase(replayBase)

	t:tdeq(calls, {
		"write",
		"import:1.5",
	})
end

---@param t testing.T
function test.save_replay_base_exports_and_writes_play_config(t)
	local calls = {}
	local replayBase = {
		exportReplayBase = function(_, play_config)
			table.insert(calls, "export")
			play_config.rate = 2
		end,
	}
	local configModel = createConfigModel(calls)

	ModifierConfigPersistence(configModel):saveReplayBase(replayBase)

	t:tdeq(calls, {
		"export",
		"write",
	})
	t:eq(configModel.configs.play.rate, 2)
end

return test
