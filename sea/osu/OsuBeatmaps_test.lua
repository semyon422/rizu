local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local OsuBeatmaps = require("sea.osu.OsuBeatmaps")
local OsuRepo = require("sea.osu.repos.OsuRepo")

local test = {}

local function create_ctx(api)
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:remove()
	db:open()

	local osu_repo = OsuRepo(db.models)
	local osu_beatmaps = OsuBeatmaps(api, osu_repo)

	return {
		db = db,
		osu_repo = osu_repo,
		osu_beatmaps = osu_beatmaps,
	}
end

---@param t testing.T
function test.caches_real_beatmap(t)
	local calls = 0
	local api = {}
	---@cast api sea.OsuApi

	function api:beatmaps_lookup(params)
		calls = calls + 1
		return {
			id = 11,
			beatmapset_id = 22,
			checksum = params.checksum,
			status = "ranked",
		}
	end

	local ctx = create_ctx(api)
	local beatmap = assert(ctx.osu_beatmaps:getOrCreateOsuBeatmapByHash("abc", 123))
	local cached = assert(ctx.osu_repo:getBeatmapByHash("abc"))
	ctx.db:close()

	t:eq(calls, 1)
	t:eq(beatmap.id, 11)
	t:eq(beatmap.beatmapset_id, 22)
	t:eq(beatmap.status, "ranked")
	t:eq(cached.id, 11)
	t:eq(cached.beatmapset_id, 22)
	t:eq(cached.status, "ranked")
end

---@param t testing.T
function test.caches_missing_beatmap(t)
	local calls = 0
	local api = {}
	---@cast api sea.OsuApi

	function api:beatmaps_lookup(params)
		calls = calls + 1
		return {
			checksum = params.checksum,
			error = "Not found",
		}
	end

	local ctx = create_ctx(api)
	local beatmap = assert(ctx.osu_beatmaps:getOrCreateOsuBeatmapByHash("missing-hash", 456))
	local beatmap_again = assert(ctx.osu_beatmaps:getOrCreateOsuBeatmapByHash("missing-hash", 789))
	local cached = assert(ctx.osu_repo:getBeatmapByHash("missing-hash"))
	ctx.db:close()

	t:eq(calls, 1)
	t:eq(beatmap.id, nil)
	t:eq(beatmap.beatmapset_id, nil)
	t:eq(beatmap.status, "missing")
	t:eq(beatmap.hash, "missing-hash")
	t:eq(beatmap_again.status, "missing")
	t:eq(cached.status, "missing")
	t:eq(cached.id, nil)
	t:eq(cached.beatmapset_id, nil)
end

return test
