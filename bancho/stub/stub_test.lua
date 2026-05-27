--- Tests for bancho stub modules.

local stub = require("bancho.stub")

local test = {}

function test.bcrypt_hasher(t)
	local h = stub.BcryptHasher()
	h:set("TestUser", "abc123")

	t:eq(h:verify("TestUser", "abc123"), true)
	t:eq(h:verify("TestUser", "wrong"), false)
	t:eq(h:verify("Unknown", "abc123"), false)
end

function test.repo_users(t)
	local r = stub.Repo()
	r:addUser({id = 1, name = "TestUser", priv = 1})

	t:eq(r:findUser(1).name, "TestUser")
	t:eq(r:findUserByName("testuser").name, "TestUser")
	t:eq(r:findUser(999), nil)
end

function test.repo_scores(t)
	local r = stub.Repo()
	r:addScore("map_md5_1", {mode = 0, score = 123456})
	r:addScore("map_md5_1", {mode = 0, score = 654321})
	r:addScore("map_md5_1", {mode = 1, score = 111111})

	local scores = r:findScores("map_md5_1", 0)
	t:eq(#scores, 2)

	local scores2 = r:findScores("map_md5_1", 1)
	t:eq(#scores2, 1)
end

function test.repo_beatmaps(t)
	local r = stub.Repo()
	r:addBeatmap({md5 = "abc123", id = 1, status = 2})

	t:eq(r:findBeatmap("abc123").id, 1)
	t:eq(r:findBeatmap("xyz789"), nil)
end

function test.http_client(t)
	local hc = stub.HttpClient()
	hc:register("https://osu.direct/api/get_beatmaps", {
		status_code = 200,
		data = {
			{beatmap_id = 1, file_md5 = "abc123"},
		},
	})

	local resp = hc:get("https://osu.direct/api/get_beatmaps")
	t:eq(resp.status_code, 200)
	t:eq(#resp.json(), 1)
end

function test.http_client_not_found(t)
	local hc = stub.HttpClient()
	local resp = hc:get("https://unknown.url/api")
	t:eq(resp.status_code, 404)
	t:eq(resp.json(), nil)
end

function test.geo_locator(t)
	local gl = stub.GeoLocator("JP")
	local result = gl:lookup("1.2.3.4")
	t:eq(result.acronym, "JP")
end

function test.performance_calculator(t)
	local pc = stub.PerformanceCalculator(75.5, 4.2)
	local pp, sr = pc:calculate({n300 = 100})
	t:eq(pp, 75.5)
	t:eq(sr, 4.2)
end

return test
