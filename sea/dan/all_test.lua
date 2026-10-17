local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local User = require("sea.access.User")
local Chartmeta = require("sea.chart.Chartmeta")
local Chartplay = require("sea.chart.Chartplay")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local DanClearsRepo = require("sea.dan.repos.DanClearsRepo")
local Dans = require("sea.dan.Dans")
local dan_list = require("sea.dan.dan_list")

local test = {}

local function create_test_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())

	db.path = ":memory:"

	db:remove()
	db:open()

	local models = db.models
	local charts_repo = ChartsRepo(models)
	local dan_clears_repo = DanClearsRepo(models)

	local user = User()
	user.id = 1
	user.play_time = 1e6

	return {
		db = db,
		user = user,
		dans = Dans(charts_repo, dan_clears_repo),
		charts_repo = charts_repo,
	}
end

---@param hash string
---@param index number
---@param time number
---@return sea.Chartplay
local function new_chartplay(hash, index, time)
	local t = {
		user_id = 1,
		compute_state = "valid",
		computed_at = time,
		submitted_at = time,
		hash = hash,
		index = index,
		rate = 1,
		mode = "mania",
		nearest = false,
		tap_only = false,
		custom = false,
		const = false,
		pause_count = 0,
		created_at = time,
		rate_type = "linear",
		accuracy = 0,
		replay_hash = ("%032x"):format(math.floor(time * 1000) + index),
		judges = {},
		modifiers = {},
		max_combo = 0,
		miss_count = 0,
		not_perfect_count = 0,
		rating = 0,
		rating_msd = 0,
		rating_pp = 0,
		pass = true,
	}
	setmetatable(t, Chartplay)
	return t
end

---@param hash string
---@param index number?
local function new_chartmeta(hash, index)
	local t = {
		hash = hash,
		index = index or 1,
		created_at = 0,
		computed_at = 0,
		inputmode = "4key",
		format = "osu"
	}
	setmetatable(t, Chartmeta)
	return t
end

---@param t testing.T
function test.is_dan(t)
	local dans = Dans()

	local random = Chartmeta()
	random.hash = "123456789"
	random.index = 1

	local delta_dan = Chartmeta()
	delta_dan.hash = "6432f864b074264c230604cfe142edb0"
	delta_dan.index = 1

	t:eq(dans:isDan(random), false)
	t:eq(dans:isDan(delta_dan), true)

	local alpha_dan = dan_list[11]
	t:eq(dans:isDan(alpha_dan.chartmeta_keys[1]), true)

	local bms_1st_chart = Chartmeta()
	bms_1st_chart.hash = "test1"
	bms_1st_chart.index = 1
	local bms_4th_chart = Chartmeta()
	bms_4th_chart.hash = "test4"
	bms_4th_chart.index = 1
	t:eq(dans:isDan(bms_1st_chart), false)
	t:eq(dans:isDan(bms_4th_chart), true)
end

---@param t testing.T
function test.submit_dan(t)
	local ctx = create_test_ctx()
	local time = 5000

	--chartplay.accuracy = 0.025 -- 79.94%
	--chartplay.accuracy = 0.024 -- 81.75%

	local delta_dan = new_chartmeta("6432f864b074264c230604cfe142edb0")
	delta_dan.timings = Timings("osuod", 9)
	delta_dan.subtimings = Subtimings("scorev", 1)
	ctx.charts_repo:createChartmeta(delta_dan)

	local chartplay = Chartplay()
	chartplay.id = 1
	chartplay.rate = 1
	chartplay.accuracy = 0.025 -- not a clear
	chartplay.timings = Timings("osuod", 0) -- wrong timings
	chartplay.pause_count = 1

	local _, err = ctx.dans:submit(ctx.user, chartplay, delta_dan, time)
	t:eq(err, "pauses are not allowed")

	chartplay.pause_count = 0
	_, err = ctx.dans:submit(ctx.user, chartplay, delta_dan, time)
	t:eq(err, "unsuitable timings")

	chartplay.timings = Timings("osuod", 9)
	_, err = ctx.dans:submit(ctx.user, chartplay, delta_dan, time)
	t:eq(err, "not cleared")

	chartplay.accuracy = 0.024
	local dan_clear, _ = ctx.dans:submit(ctx.user, chartplay, delta_dan, time)
	---@cast dan_clear -?

	t:eq(dan_clear.time, time)
	t:eq(dan_clear.user_id, ctx.user.id)
	t:eq(dan_clear.dan_id, dan_list[14].id)
	t:tdeq(dan_clear.chartplay_ids, {chartplay.id})
	t:eq(dan_clear.rate, 1)

	chartplay = Chartplay()
	chartplay.id = 2
	chartplay.rate = 1
	chartplay.accuracy = 0.02
	chartplay.timings = Timings("osuod", 9)
	chartplay.subtimings = Subtimings("scorev", 1)
	chartplay.pause_count = 0
	_, err = ctx.dans:submit(ctx.user, chartplay, delta_dan, time)
	t:eq(err, "already cleared")

	chartplay.rate = 1.05
	dan_clear, _ = ctx.dans:submit(ctx.user, chartplay, delta_dan, time)
	t:assert(dan_clear ~= nil)
	---@cast dan_clear -?

	t:eq(dan_clear.time, time)
	t:eq(dan_clear.user_id, ctx.user.id)
	t:eq(dan_clear.dan_id, dan_list[14].id)
	t:eq(dan_clear.chartplay_ids[1], chartplay.id)
	t:eq(dan_clear.rate, 1.05)
end

---@param t testing.T
function test.submit_bms_dan(t)
	local ctx = create_test_ctx()
	local time = 5000

	local dan = dan_list[99999]

	local cmk = dan.chartmeta_keys
	local cm1 = new_chartmeta(cmk[1].hash)
	local cm2 = new_chartmeta(cmk[2].hash)
	local cm3 = new_chartmeta(cmk[3].hash)
	local cm4 = new_chartmeta(cmk[4].hash)
	ctx.charts_repo:createChartmeta(cm1)
	ctx.charts_repo:createChartmeta(cm2)
	ctx.charts_repo:createChartmeta(cm3)
	ctx.charts_repo:createChartmeta(cm4)

	local chartplay = Chartplay()
	chartplay.id = 1
	chartplay.rate = 1
	chartplay.miss_count = 0
	chartplay.accuracy = 0.02
	chartplay.timings = Timings("bmsrank", 1)
	chartplay.pause_count = 0

	local _, err = ctx.dans:submit(ctx.user, chartplay, cm4, time)
	t:eq(err, "invalid chartplay order")

	local c3 = new_chartplay(cmk[3].hash, 1, 1)
	local c1 = new_chartplay(cmk[1].hash, 1, 2)
	local c2 = new_chartplay(cmk[2].hash, 1, 3)
	local c4 = new_chartplay(cmk[4].hash, 1, 4)
	ctx.charts_repo:createChartplay(c3)
	ctx.charts_repo:createChartplay(c2)
	ctx.charts_repo:createChartplay(c1)
	ctx.charts_repo:createChartplay(c4)
	_, err = ctx.dans:submit(ctx.user, c4, cm4, time)
	t:eq(err, "invalid chartplay order")

	c1 = new_chartplay(cmk[1].hash, 1, 5)
	c1.miss_count = 50
	c2 = new_chartplay(cmk[2].hash, 1, 6)
	c2.miss_count = 100
	c3 = new_chartplay(cmk[3].hash, 1, 7)
	c3.miss_count = 40
	c4 = new_chartplay(cmk[4].hash, 1, 8)
	c4.miss_count = 100
	ctx.charts_repo:createChartplay(c1)
	ctx.charts_repo:createChartplay(c2)
	ctx.charts_repo:createChartplay(c3)
	ctx.charts_repo:createChartplay(c4)
	_, err = ctx.dans:submit(ctx.user, c4, cm4, time)
	t:eq(err, "not cleared")

	c1 = new_chartplay(cmk[1].hash, 1, 9)
	c2 = new_chartplay(cmk[2].hash, 1, 10)
	c3 = new_chartplay(cmk[3].hash, 1, 11)
	c4 = new_chartplay(cmk[4].hash, 1, 12)
	c1 = ctx.charts_repo:createChartplay(c1)
	c2 = ctx.charts_repo:createChartplay(c2)
	c3 = ctx.charts_repo:createChartplay(c3)
	c4 = ctx.charts_repo:createChartplay(c4)
	local dan_clear, _ = ctx.dans:submit(ctx.user, c4, cm4, time)
	---@cast dan_clear -?
	t:eq(dan_clear.user_id, ctx.user.id)
	t:tdeq(dan_clear.chartplay_ids, {c1.id, c2.id, c3.id, c4.id})
end

---@param t testing.T
function test.mods(t)
	local ctx = create_test_ctx()
	local time = 5000

	local delta_dan = new_chartmeta("6432f864b074264c230604cfe142edb0")
	delta_dan.timings = Timings("osuod", 9)
	delta_dan.subtimings = Subtimings("scorev", 1)
	delta_dan = ctx.charts_repo:createChartmeta(delta_dan)

	local chartplay = Chartplay()
	chartplay.id = 1
	chartplay.rate = 1
	chartplay.accuracy = 0.02
	chartplay.timings = Timings("osuod", 9)
	chartplay.subtimings = Subtimings("scorev", 1)
	chartplay.pause_count = 0
	chartplay.modifiers = { { id = 1 } }
	local _, err = ctx.dans:submit(ctx.user, chartplay, delta_dan, time)
	t:eq(err, "modifiers are not allowed")

	chartplay.modifiers = {}
	chartplay.columns_order = { 1, 3, 2, 4 }
	_, err = ctx.dans:submit(ctx.user, chartplay, delta_dan, time)
	t:eq(err, "invalid column order")

	chartplay.columns_order = { 2, 1, 3, 4 }
	_, err = ctx.dans:submit(ctx.user, chartplay, delta_dan, time)
	t:eq(err, "invalid column order")

	chartplay.columns_order = { 4, 3, 2, 1 }
	local dan_clear, _ = ctx.dans:submit(ctx.user, chartplay, delta_dan, time)
	t:assert(dan_clear ~= nil)
end

---@param t testing.T
function test.bms_mods(t)
	local ctx = create_test_ctx()
	local time = 5000

	local dan = dan_list[99999]

	local cmk = dan.chartmeta_keys
	local cm1 = new_chartmeta(cmk[1].hash)
	local cm2 = new_chartmeta(cmk[2].hash)
	local cm3 = new_chartmeta(cmk[3].hash)
	local cm4 = new_chartmeta(cmk[4].hash)
	ctx.charts_repo:createChartmeta(cm1)
	ctx.charts_repo:createChartmeta(cm2)
	ctx.charts_repo:createChartmeta(cm3)
	ctx.charts_repo:createChartmeta(cm4)

	local chartplay = Chartplay()
	chartplay.id = 1
	chartplay.rate = 1
	chartplay.miss_count = 0
	chartplay.accuracy = 0.02
	chartplay.timings = Timings("bmsrank", 1)
	chartplay.pause_count = 0

	local c1 = new_chartplay(cmk[1].hash, 1, 1)
	c1.modifiers = {{id = 2}}
	local c2 = new_chartplay(cmk[2].hash, 1, 2)
	local c3 = new_chartplay(cmk[3].hash, 1, 3)
	local c4 = new_chartplay(cmk[4].hash, 1, 4)
	ctx.charts_repo:createChartplay(c3)
	ctx.charts_repo:createChartplay(c2)
	ctx.charts_repo:createChartplay(c1)
	ctx.charts_repo:createChartplay(c4)
	local _, err = ctx.dans:submit(ctx.user, chartplay, cm4, time)
	t:eq(err, "modifiers are not allowed")

	c1 = new_chartplay(cmk[1].hash, 1, 5)
	c1.rate = 1.05
	c2 = new_chartplay(cmk[2].hash, 1, 6)
	c3 = new_chartplay(cmk[3].hash, 1, 7)
	c4 = new_chartplay(cmk[4].hash, 1, 8)
	ctx.charts_repo:createChartplay(c3)
	ctx.charts_repo:createChartplay(c2)
	ctx.charts_repo:createChartplay(c1)
	ctx.charts_repo:createChartplay(c4)
	_, err = ctx.dans:submit(ctx.user, chartplay, cm4, time)
	t:eq(err, "different rates in chartplays")
end

return test
