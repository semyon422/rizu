local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local ComputeState = require("sea.compute.ComputeState")
local TestChartFactory = require("sea.chart.TestChartFactory")

local test = {}

local function create_db()
	local server = ServerSqliteDatabase(LjsqliteDatabase())
	server.path = ":memory:"
	server:open()
	return server
end

---@param server sea.ServerSqliteDatabase
---@param id integer
---@param state sea.ComputeState
local function create_rows(server, id, state)
	local hash = string.format("%032d", id)
	server.models.chartplays:create(TestChartFactory():createChartplay({
		id = id, hash = hash, replay_hash = hash, compute_state = state, submitted_at = id * 10,
	}))
	server.models.chartfiles:create({id = id, hash = hash, name = "chart.osu", size = id * 100,
		creator_id = 1, compute_state = state, computed_at = 0, submitted_at = id * 10})
end

---@param t testing.T
---@param server sea.ServerSqliteDatabase
---@param id integer
---@param state sea.ComputeState
local function check_rows(t, server, id, state)
	for _, name in ipairs({"chartplays", "chartfiles"}) do
		local raw = server.db:query("SELECT compute_state, typeof(compute_state) AS storage_type FROM " .. name .. " WHERE id = ?", {id})[1]
		t:eq(raw.storage_type, "integer")
		t:eq(tonumber(raw.compute_state), ComputeState:encode(state))
		t:eq(assert(server.models[name]:find({id = id})).compute_state, state)
	end
end

---@param t testing.T
function test.enum_round_trip_and_conditions(t)
	local server = create_db()
	t:eq(server.db:user_version(), 12)
	for id, state in ipairs(ComputeState:list()) do
		create_rows(server, id, state)
		check_rows(t, server, id, state)
		t:eq(server.models.chartplays:count({compute_state = state}), 1)
		t:eq(server.models.chartfiles:count({compute_state = state}), 1)
	end
	for _, name in ipairs({"chartplays", "chartfiles"}) do
		server.models[name]:update({compute_state = "valid"}, {id = 1})
	end
	check_rows(t, server, 1, "valid")
	server:close()
end

---@param t testing.T
function test.version_11_mixed_states_migrate_without_changing_scores(t)
	local server = create_db()
	local states = {"new", "valid", "invalid", "new", "valid", "invalid"}
	for id, state in ipairs(states) do
		create_rows(server, id, state)
		local raw_state = id <= 3 and state or ComputeState:encode(state)
		server.db:query("UPDATE chartplays SET compute_state = ? WHERE id = ?", {raw_state, id})
		server.db:query("UPDATE chartfiles SET compute_state = ? WHERE id = ?", {raw_state, id})
	end
	server.db:user_version(11)
	server:migrate()
	t:eq(server.db:user_version(), 12)
	for id, state in ipairs(states) do
		check_rows(t, server, id, state)
		local play = assert(server.models.chartplays:find({id = id}))
		t:eq(play.replay_hash, string.format("%032d", id))
		t:eq(play.submitted_at, id * 10)
		t:eq(assert(server.models.chartfiles:find({id = id})).size, id * 100)
	end
	for _, name in ipairs({"chartplays", "chartplayviews", "chartplays_list", "best_chartdiff_chartplays", "best_chartmeta_chartplays"}) do
		---@type sea.Chartplay[]
		local rows = server.models[name]:select({compute_state = "valid"})
		t:eq(#rows, 2)
		for _, row in ipairs(rows) do t:eq(row.compute_state, "valid") end
	end
	server:migrate()
	t:eq(server.models.chartplays:count(), 6)
	t:eq(server.models.chartfiles:count(), 6)
	server.db:user_version(11)
	server:migrate()
	for id, state in ipairs(states) do check_rows(t, server, id, state) end
	server:close()
end

---@param t testing.T
function test.unknown_states_roll_back_the_whole_migration(t)
	for _, name in ipairs({"chartfiles", "chartplays"}) do
		for _, bad_state in ipairs({"unknown", 3}) do
			local server = create_db()
			create_rows(server, 1, "valid")
			server.db:query("UPDATE chartfiles SET compute_state = 'valid'")
			server.db:query("UPDATE chartplays SET compute_state = 'valid'")
			server.db:query("UPDATE " .. name .. " SET compute_state = ?", {bad_state})
			server.db:user_version(11)
			t:has_error(server.migrate, server)
			t:eq(server.db:user_version(), 11)
			for _, table_name in ipairs({"chartfiles", "chartplays"}) do
				local raw = server.db:query("SELECT compute_state FROM " .. table_name)[1]
				if table_name ~= name then
					t:eq(raw.compute_state, "valid")
				elseif type(bad_state) == "number" then
					t:eq(tonumber(raw.compute_state), bad_state)
				else
					t:eq(raw.compute_state, bad_state)
				end
			end
			server.db:query("UPDATE " .. name .. " SET compute_state = 'valid'")
			server:migrate()
			check_rows(t, server, 1, "valid")
			server:close()
		end
	end
end

return test
