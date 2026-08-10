local pkg = require("aqua.pkg")

pkg.import_lua()

pkg.addc()
pkg.addc("3rd-deps/lib")
pkg.addc("bin/lib")
pkg.addc("tree/lib/lua/5.1")
pkg.add()
pkg.add("3rd-deps/lua")
pkg.add("aqua")
pkg.add("ncdk")
pkg.add("chartbase")
pkg.add("libchart")
pkg.add("tree/share/lua/5.1")

pkg.export_lua()
pcall(pkg.export_love)

local json = require("web.json")
local io_util = require("io_util")
local table_util = require("table_util")
local stbl = require("stbl")
local socket = require("socket")
local time_util = require("time_util")
local ComputeContext = require("sea.compute.ComputeContext")
local ActivityTimezones = require("sea.activity.ActivityTimezones")

-- lua-nginx-module bug fix
coroutine.wrap = require("icc.co").wrap

local App = require("sea.app.App")
local app_config = require("server-state.app_config")
local app = App(app_config)

local domain = app.domain
local chartplays = domain.chartplays
local compute_tasks = domain.compute_tasks
local charts_computer = domain.charts_computer
local leaderboards = domain.leaderboards

local function run_chartplays(task)
	local start_time = socket.gettime()
	local count = 0

	local chartplays = charts_computer:getChartplaysComputed(task.created_at, task.state, 10)
	while #chartplays > 0 do
		for _, chartplay in ipairs(chartplays) do
			local ret, err = charts_computer:computeChartplay(chartplay)
			if not ret then
				print(err)
			end
		end

		task = compute_tasks:step(task, #chartplays)
		chartplays = charts_computer:getChartplaysComputed(task.created_at, task.state, 10)

		count = count + #chartplays
		local dt = socket.gettime() - start_time
		local speed = count / dt
		print(("%s / %s - %0.2f rps - %s / %s - %0.2f%%"):format(
			time_util.format(dt),
			time_util.format((task.total - task.current) / speed),
			speed,
			task.current,
			task.total,
			task.current / task.total * 100
		))
	end
end

local function run_total_rating(task)
	local lbs = domain.leaderboards:getLeaderboards()
	local users = domain.users:getUsers()

	for i, user in ipairs(users) do
		for _, lb in ipairs(lbs) do
			-- task = compute_tasks:step(task, user, lb)
			leaderboards:updateLeaderboardUser(lb, user.id, true)
		end
		print(i)
	end
end

local cmds = {}

function cmds.run(id)
	id = assert(tonumber(id))
	local task = assert(compute_tasks:getComputeTask(id))
	if task.target == "chartplays" then
		run_chartplays(task)
	elseif task.target == "total_rating" then
		run_total_rating(task)
	end

	print("done")
end

function cmds.start_chartplays(state)
	assert(state)
	local time = os.time()
	local total = charts_computer:getChartplaysComputedCount(time, state)
	local task = compute_tasks:createComputeTask(time, "chartplays", state, total)
	cmds.list()
end

function cmds.start_total_rating()
	local total = domain.users:getUsersCount() * leaderboards:getLeaderboardsCount()
	local task = compute_tasks:createComputeTask(os.time(), "total_rating", "new", total)
	cmds.list()
end

function cmds.compute_jobs(state, limit)
	limit = limit and assert(tonumber(limit)) or 100
	for _, job in ipairs(domain.compute_jobs:getJobs(state, limit)) do
		print(stbl.encode(job))
	end
end

function cmds.requeue_compute_job(id)
	id = assert(tonumber(id))
	local job, err = domain.compute_jobs:requeue(id)
	assert(job, err)
	print(stbl.encode(job))
end

function cmds.compute_chartplay(id)
	id = assert(tonumber(id))

	local _chartplay = assert(chartplays:getChartplay(id))
	local _chartdiff = chartplays.charts_repo:getChartdiffByChartdiffKey(_chartplay)

	print("-- Saved chartplay")
	print(stbl.encode(_chartplay))

	print("-- Saved chartdiff")
	if _chartdiff then
		_chartdiff.notes_preview = "hidden"
		print(stbl.encode(_chartdiff))
	else
		print("missing")
	end

	local compute_data_loader = domain.compute_data_loader

	local chart_file_data = assert(compute_data_loader:requireChart(_chartplay.hash))
	local replay_and_data = assert(compute_data_loader:requireReplay(_chartplay.replay_hash))

	local ctx = ComputeContext()

	assert(ctx:fromFileData(
		chart_file_data.name,
		chart_file_data.data,
		_chartplay.index
	))

	local replay = replay_and_data.replay

	ctx:applyModifierReorder(replay)

	local chartdiff = ctx:computeBase(replay)
	chartdiff.notes_preview = "hidden"

	local chartplay_computed = assert(ctx:computeReplay(replay))

	-- chartplay:importChartplayBase(replay)
	-- chartplay:importChartplayComputed(chartplay_computed)

	print("-- Computed chartplay")
	print(stbl.encode(chartplay_computed))

	print("-- Computed chartdiff")
	print(stbl.encode(chartdiff))
end

function cmds.activity_graph()
	local users = app.domain.users:getUsers()

	for _, user in ipairs(users) do
		app.app_db.db:query("BEGIN")
		app.app_db.db:query("DELETE FROM user_activity_days WHERE user_id = ?", {user.id})

		---@type {submitted_at: integer}[]
		local plays = app.app_db.db:query("SELECT submitted_at FROM chartplays WHERE submitted_at > 0 AND user_id = ?", {user.id})

		---@type {[integer]: {[string]: integer}}
		local activity = {}

		for _, p in ipairs(plays) do
			local submitted_at = tonumber(p.submitted_at)
			for _, tz in ipairs(ActivityTimezones) do
				local tz_key = tz:encode()

				local adjusted_time = submitted_at + tz:seconds()
				local ymd = os.date("!%Y-%m-%d", adjusted_time)

				activity[tz_key] = activity[tz_key] or {}
				activity[tz_key][ymd] = (activity[tz_key][ymd] or 0) + 1
			end
		end

		for tz_key, t in pairs(activity) do
			for ymd, count in pairs(t) do
				local y, m, d = ymd:match("(%d+)-(%d+)-(%d+)")
				app.app_db.db:query([[
					INSERT INTO user_activity_days (user_id, timezone, year, month, day, count)
					VALUES (?, ?, ?, ?, ?, ?)
				]], {user.id, tz_key, tostring(y), tostring(m), tostring(d), count})
			end
		end

		app.app_db.db:query("COMMIT")

		print(user.id, #plays)
	end
end

function cmds.update_rank_history(id)
	id = assert(tonumber(id))
	local lb = assert(app.domain.leaderboards:getLeaderboard(id))

	app.app_db.db:query("BEGIN")
	app.domain.leaderboards:updateHistories(os.time(), lb)
	app.app_db.db:query("COMMIT")
end

function cmds.update_rank_history_all()
	local lbs = app.domain.leaderboards:getLeaderboards()
	for _, lb in ipairs(lbs) do
		print(lb.id)
		app.app_db.db:query("BEGIN")
		app.domain.leaderboards:updateHistories(os.time(), lb)
		app.app_db.db:query("COMMIT")
	end
end

function cmds.compute_rank_history(id)
	id = assert(tonumber(id))
	local lb = assert(app.domain.leaderboards:getLeaderboard(id))

	app.app_db.db:query("BEGIN")
	app.domain.leaderboards:computeHistories(os.time(), lb)
	app.app_db.db:query("COMMIT")
end

function cmds.ranks()
	app.repos.leaderboards_repo:updateLeaderboardUserRanks()
end

function cmds.chartplays_count()
	app.repos.users_repo:updateChartplaysCount()
end

function cmds.play_time()
	app.repos.users_repo:updatePlayTime()
end

function cmds.chartmetas_count()
	app.repos.users_repo:updateChartmetasCount()
end

function cmds.auth_codes()
	local codes = app.app_db.db:query([[
		SELECT
			auth_codes.code,
			auth_codes.type,
			users.id,
			users.name,
			users.email
		FROM auth_codes
		INNER JOIN users ON
			users.id = auth_codes.user_id
		WHERE
			auth_codes.used = 0
		;
	]])

	for _, c in ipairs(codes) do
		print(c.code, tonumber(c.id), c.name, c.email)
	end
end

function cmds.import_difftable(path, tag)
	assert(path, "missing path")
	assert(tag, "missing tag")

	local difftable = app.repos.difftables_repo:getDifftableByTag(tag)
	if not difftable then
		print("missing difftable")
		return
	end

	---@type {[string]: {level: string}[]}
	local data = json.decode(io_util.read_file(path))

	for _, dt_cm in ipairs(app.repos.difftables_repo:getDifftableChartmetas(difftable.id)) do
		data[dt_cm.hash] = nil
	end

	print(("adding %d hashes"):format(#table_util.keys(data)))

	local DifftableChartmeta = require("sea.difftables.DifftableChartmeta")

	local time = os.time()

	---@type sea.DifftableChartmeta[]
	local dt_cms = {}
	for hash, charts in pairs(data) do
		for i, chart in ipairs(charts) do
			local dt_cm = DifftableChartmeta()
			dt_cm.user_id = 0
			dt_cm.difftable_id = difftable.id
			dt_cm.hash = hash
			dt_cm.index = i
			dt_cm.level = tonumber(chart.level) or 0
			dt_cm.is_deleted = false
			dt_cm.created_at = time
			dt_cm.updated_at = time
			table.insert(dt_cms, dt_cm)
		end
	end

	for _, t in ipairs(table_util.slices(dt_cms, 100)) do
		app.repos.difftables_repo:insertDifftableChartmetas(t)
	end
end

function cmds.check_chartplay(lb_id, cp_id)
	lb_id = assert(tonumber(lb_id))
	cp_id = assert(tonumber(cp_id))

	local leaderboards_repo = app.repos.leaderboards_repo
	local charts_repo = app.repos.charts_repo

	local lb = assert(leaderboards_repo:getLeaderboard(lb_id))
	local cp = assert(charts_repo:getChartplay(cp_id))

	print(leaderboards_repo:checkChartplay(lb, cp))
end

function cmds.osu_api_check(hash)
	assert(hash)
	local beatmap = domain.osu_beatmaps:getOrCreateOsuBeatmapByHash(hash, os.time())
	print(stbl.encode(beatmap))
end

function cmds.delete(id)
	id = assert(tonumber(id))
	compute_tasks:deleteProcess(id)
	cmds.list()
end

function cmds.list()
	local cps = compute_tasks:getComputeTasks()
	print("Compute processes:")
	for _, cp in ipairs(cps) do
		print(stbl.encode(cp))
	end
end

function cmds.migrate()
	local ServerMigration = require("sea.storage.old_server.ServerMigration")
	local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
	local RestyMysqlDatabase = require("rdb.db.RestyMysqlDatabase")
	local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")

	local src_db = RestyMysqlDatabase()
	src_db:open("backend", "username", "password", "127.0.0.1", 3306)

	local dst_db = ServerSqliteDatabase(LjsqliteDatabase())
	dst_db.path = "server-state/server.db"
	dst_db:open()

	dst_db.db:exec("BEGIN")
	local mig = ServerMigration(src_db, dst_db.db)
	mig:migrate()
	dst_db.db:exec("COMMIT")
end

local command = arg[1]
local f = cmds[command]
if f then
	app:load()
	f(unpack(arg, 2))
else
	print("unknown command")
end
