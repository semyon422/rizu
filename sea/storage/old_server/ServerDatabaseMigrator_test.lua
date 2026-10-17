local ServerDatabaseMigrator = require("sea.storage.old_server.ServerDatabaseMigrator")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local SharedMemory = require("web.nginx.SharedMemory")
local ServerRepo = require("sea.storage.old_server.ServerRepo")
local Repos = require("sea.app.Repos")
local Timezone = require("sea.activity.Timezone")

local TableOrm = require("rdb.TableOrm")
local Models = require("rdb.Models")
local autoload = require("autoload")

local test = {}

local function create_test_ctx()
	local src_db = LjsqliteDatabase()
	src_db:open(":memory:")

	local src_models = Models(autoload("sea.storage.old_server.models", true), TableOrm(src_db))
	local old_repo = ServerRepo(src_models)

	local f = assert(io.open("sea/storage/old_server/db.sql"))
	local sql = f:read("*a")
	f:close()

	src_db:exec(sql)

	local dst_db = ServerSqliteDatabase(LjsqliteDatabase())
	dst_db.path = ":memory:"
	dst_db:open()

	local repos = Repos(dst_db.models, SharedMemory())

	local migrator = ServerDatabaseMigrator(old_repo, repos)

	-- db.orm:debug(true)

	return {
		src_db = src_db,
		src_models = src_models,
		old_repo = old_repo,
		repos = repos,
		migrator = migrator,
	}
end

---@param t testing.T
function test.chartfiles(t)
	local ctx = create_test_ctx()

	-- chart files
	ctx.src_models.files:create({
		hash = "00000000000000000000000000000000",
		name = "chart.osu",
		format = "osu",
		storage = "notecharts",
		size = 10,
		created_at = 100,
	})
	ctx.src_models.files:create({
		hash = "11111111111111111111111111111111",
		name = "chart.sm",
		format = "stepmania",
		storage = "notecharts",
		size = 20,
		created_at = 200,
	})

	-- replay files
	ctx.src_models.files:create({
		hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		name = "replay1",
		format = "undefined",
		storage = "replays",
		size = 30,
		created_at = 300,
	})

	local count = ctx.migrator:migrateChartfiles()
	t:eq(count, 2)

	local chartfiles = ctx.repos.chartfiles_repo:getChartfiles()
	t:eq(#chartfiles, 2)

	t:tdeq(chartfiles[1], {
		id = 1,
		hash = "00000000000000000000000000000000",
		name = "chart.osu",
		size = 10,
		compute_state = "new",
		computed_at = 0,
		creator_id = 0,
		submitted_at = 100,
	})
end

---@param t testing.T
function test.user_roles(t)
	local ctx = create_test_ctx()

	ctx.src_models.user_roles:create({
		user_id = 1,
		role = "creator",
		expires_at = 110,
		total_time = 10,
	})

	local count = ctx.migrator:migrateUserRoles()
	t:eq(count, 1)

	local user_roles = ctx.repos.users_repo:getUserRoles(1)
	t:eq(#user_roles, 1)

	t:tdeq(user_roles[1], {
		id = 1,
		user_id = 1,
		role = "owner",
		started_at = 0,
		expires_at = 110,
		total_time = 10,
	})
end

---@param t testing.T
function test.sessions(t)
	local ctx = create_test_ctx()

	ctx.src_models.sessions:create({
		user_id = 1,
		active = true,
		ip = "127.0.0.1",
		created_at = 10,
		updated_at = 20,
	})

	local count = ctx.migrator:migrateSessions()
	t:eq(count, 1)

	local sessions = ctx.repos.users_repo:getSessionsInsecure(1)
	t:eq(#sessions, 1)

	t:tdeq(sessions[1], {
		id = 1,
		user_id = 1,
		active = true,
		ip = "127.0.0.1",
		created_at = 10,
		updated_at = 20,
	})
end

---@param t testing.T
function test.user_locations(t)
	local ctx = create_test_ctx()

	ctx.src_models.user_locations:create({
		user_id = 1,
		ip = "127.0.0.1",
		created_at = 10,
		updated_at = 20,
		is_register = true,
		sessions_count = 30,
	})

	local count = ctx.migrator:migrateUserLocations()
	t:eq(count, 1)

	local user_locations = ctx.repos.users_repo:getUserLocations(1)
	t:eq(#user_locations, 1)

	t:tdeq(user_locations[1], {
		id = 1,
		user_id = 1,
		ip = "127.0.0.1",
		created_at = 10,
		updated_at = 20,
		is_register = true,
		sessions_count = 30,
	})
end

---@param t testing.T
function test.users(t)
	local ctx = create_test_ctx()

	ctx.src_models.users:create({
		name = "user",
		email = "user@user.com",
		password = "password",
		latest_activity = 10,
		latest_score_submitted_at = 20,
		created_at = 30,
		is_banned = false,
		is_restricted_info = false,
		description = "desc",
		scores_count = 1000,
		notecharts_count = 500,
		notes_count = 2000,
		notecharts_upload_size = 100,
		replays_upload_size = 200,
		play_time = 300,
		color_left = 1,
		color_right = 2,
		banner = "qwerty",
		discord = "discord",
		twitter = "twitter",
		custom_link = "link",
	})

	local count = ctx.migrator:migrateUsers()
	t:eq(count, 1)

	local users = ctx.repos.users_repo:getUsersInsecure()
	t:eq(#users, 1)

	t:tdeq(users[1], {
		id = 1,
		name = "user",
		email = "user@user.com",
		password = "password",
		latest_activity = 10,
		activity_timezone = Timezone(),
		created_at = 30,
		is_banned = false,
		is_restricted_info = false,
		description = "desc",
		chartplays_count = 1000,
		chartmetas_count = 500,
		chartdiffs_count = 0,
		chartfiles_upload_size = 100,
		chartplays_upload_size = 200,
		play_time = 300,
		enable_gradient = false,
		color_left = 1,
		color_right = 2,
		avatar = "",
		banner = "qwerty",
		discord = "discord",
		country_code = "xd",
		custom_link = "link",
		user_roles = {},
	})
end


---@param t testing.T
function test.scores(t)
	local ctx = create_test_ctx()

	local chart_file = ctx.src_models.files:create({
		hash = "00000000000000000000000000000000",
		name = "chart.osu",
		format = "osu",
		storage = "notecharts",
		size = 10,
		created_at = 100,
	})

	local replay_file = ctx.src_models.files:create({
		hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		name = "replay1",
		format = "undefined",
		storage = "replays",
		size = 30,
		created_at = 300,
	})

	ctx.src_models.notecharts:create({
		file_id = chart_file.id,
		index = 1,
		created_at = 0,
		is_complete = true,
		is_valid = true,
		scores_count = 10,
		inputmode = "10key",
		difficulty = 20,
		song_title = "title",
		song_artist = "artist",
		difficulty_name = "name",
		difficulty_creator = "creator",
		level = 12,
		length = 120,
		notes_count = 1000,
	})

	ctx.src_models.scores:create({
		user_id = 1,
		notechart_id = 1,
		modifierset_id = 1,
		file_id = replay_file.id,
		inputmode = "10key",
		is_complete = true,
		is_valid = true,
		is_ranked = true,
		is_top = true,
		created_at = 10,
		score = 0.03,
		accuracy = 0.02,
		max_combo = 1000,
		misses_count = 10,
		difficulty = 20,
		rating = 19,
		rate = 1.0717734625363,
		const = true,
	})

	local count = ctx.migrator:migrateChartplays()
	t:eq(count, 1)

	local chartplays = ctx.repos.charts_repo:getChartplays()
	t:eq(#chartplays, 1)

	t:tdeq(chartplays[1], {
		id = 1,
		user_id = 1,
		compute_state = "new",
		computed_at = 0,
		submitted_at = 10,
		replay_hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		pause_count = 0,
		created_at = 10,
		hash = "00000000000000000000000000000000",
		index = 1,
		modifiers = {},
		rate = 1.072,
		mode = "mania",
		nearest = false,
		tap_only = false,
		timings = nil,
		subtimings = nil,
		healths = nil,
		columns_order = nil,
		custom = false,
		const = true,
		rate_type = "linear",
		judges = {},
		accuracy = 0.02,
		max_combo = 1000,
		miss_count = 10,
		not_perfect_count = 0,
		pass = true,
		rating = 19,
		rating_pp = 0,
		rating_msd = 0,
	})
end

return test
