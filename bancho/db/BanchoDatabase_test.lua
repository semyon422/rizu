--- Tests for the bancho database layer.

if not pcall(require, "rdb.db.LjsqliteDatabase") then
	return {}
end

local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local BanchoDatabase = require("bancho.db.BanchoDatabase")
local Repos = require("bancho.db.repos")

local test = {}

--- Create a fresh in-memory database for testing.
local function create_db()
	local db = BanchoDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:open()
	return db
end

function test.open_and_close(t)
	local db = create_db()
	t:ne(db.models, nil)
	t:ne(db.orm, nil)
	db:close()
end

function test.user_repo_crud(t)
	local db = create_db()
	local repos = Repos(db.models)

	-- Create user with bcrypt hash (matches bancho.py pattern)
	local bcrypt = require("bcrypt")
	local pw_md5 = "5f4dcc3b5aa765d61d8327deb882cf99"
	local pw_bcrypt = bcrypt.digest(pw_md5, 10)

	local user = repos.user_repo:createUser("TestUser", "test@test.com", pw_bcrypt, "US")
	t:eq(user.name, "TestUser")
	t:ne(user.id, nil)
	t:ne(user.pw_bcrypt, "")

	-- Find by id
	local found = repos.user_repo:findUser(user.id)
	t:eq(found.name, "TestUser")

	-- Find by name
	local by_name = repos.user_repo:findUserByName("testuser")
	t:eq(by_name.name, "TestUser")

	-- Find by email
	local by_email = repos.user_repo:findByEmail("test@test.com")
	t:eq(by_email.name, "TestUser")

	-- Partial update
	repos.user_repo:partialUpdate(user.id, {priv = 1})
	local updated = repos.user_repo:findUser(user.id)
	t:eq(updated.priv, 1)

	-- Find by name and password (correct MD5 → bcrypt verify)
	local by_pw = repos.user_repo:findUserByNameAndPassword("TestUser", pw_md5)
	t:eq(by_pw.name, "TestUser")

	-- Find by name and wrong password
	local wrong_pw = repos.user_repo:findUserByNameAndPassword("TestUser", "abc123")
	t:eq(wrong_pw, nil)
	db:close()
end

function test.stats_repo_crud(t)
	local db = create_db()
	local repos = Repos(db.models)

	-- Create stats for all modes
	repos.stats_repo:createAllModes(1)
	repos.stats_repo:createAllModes(2)

	-- Get stats
	local stats = repos.stats_repo:getStats(1, 0)
	t:eq(stats.user_id, 1)
	t:eq(stats.mode, 0)
	t:eq(stats.tscore, 0)

	-- Update stats
	repos.stats_repo:updateStats(1, 0, {tscore = 100000, plays = 5, pp = 50})
	repos.stats_repo:updateStats(2, 0, {pp = 100})
	local updated = repos.stats_repo:getStats(1, 0)
	t:eq(updated.tscore, 100000)
	t:eq(updated.plays, 5)
	t:eq(updated.rank, 2)

	-- Other modes should be untouched
	local stats_taiko = repos.stats_repo:getStats(1, 1)
	t:eq(stats_taiko.tscore, 0)

	db:close()
end

function test.beatmap_repo_crud(t)
	local db = create_db()
	local repos = Repos(db.models)

	-- Add beatmap
	repos.beatmap_repo:addBeatmap({
		id = 100,
		set_id = 50,
		md5 = "abc123",
		artist = "TestArtist",
		title = "TestTitle",
		version = "Easy",
		creator = "TestCreator",
		status = 2,
		mode = 3,
		diff = 3.5,
	})

	-- Find by md5
	local bmap = repos.beatmap_repo:findBeatmap("abc123")
	t:eq(bmap.id, 100)
	t:eq(bmap.artist, "TestArtist")

	-- Find by id
	local by_id = repos.beatmap_repo:findBeatmapById(100)
	t:eq(by_id.md5, "abc123")

	-- Update counts
	repos.beatmap_repo:updateCounts("abc123", 1, 1)
	local updated = repos.beatmap_repo:findBeatmap("abc123")
	t:eq(updated.plays, 1)
	t:eq(updated.passes, 1)

	db:close()
end

function test.score_repo_crud(t)
	local db = create_db()
	local repos = Repos(db.models)

	-- Add scores
	local id1 = repos.score_repo:addScore({
		map_md5 = "map1",
		score = 100000,
		pp = 50,
		acc = 90,
		max_combo = 100,
		user_id = 1,
		mode = 3,
	})
	local id2 = repos.score_repo:addScore({
		map_md5 = "map1",
		score = 200000,
		pp = 100,
		acc = 95,
		max_combo = 200,
		user_id = 1,
		mode = 3,
	})

	-- Find best score
	local best = repos.score_repo:findBestScore("map1", 1, 3)
	t:eq(best.score, 200000)
	t:eq(best.pp, 100)

	-- Find top scores
	local top = repos.score_repo:findTopScores("map1", 3, 10)
	t:eq(#top, 2)
	t:eq(top[1].score, 200000)

	-- Find by id
	local by_id = repos.score_repo:findScore(id1)
	t:eq(by_id.score, 100000)

	db:close()
end

function test.friends_repo_crud(t)
	local db = create_db()
	local repos = Repos(db.models)

	-- Add friends
	repos.friends_repo:addFriend(1, 2)
	repos.friends_repo:addFriend(1, 3)
	repos.friends_repo:addFriend(1, 4)

	-- Get friends
	local friends = repos.friends_repo:getFriends(1)
	t:eq(#friends, 3)

	-- Remove friend
	repos.friends_repo:removeFriend(1, 3)
	local remaining = repos.friends_repo:getFriends(1)
	t:eq(#remaining, 2)

	db:close()
end

function test.favourites_repo_crud(t)
	local db = create_db()
	local repos = Repos(db.models)

	-- Add favourites
	repos.favourites_repo:addFavourite(1, 100)
	repos.favourites_repo:addFavourite(1, 200)

	-- Get favourites
	local favs = repos.favourites_repo:getFavourites(1)
	t:eq(#favs, 2)

	-- Remove favourite
	repos.favourites_repo:removeFavourite(1, 100)
	local remaining = repos.favourites_repo:getFavourites(1)
	t:eq(#remaining, 1)

	db:close()
end

function test.replay_repo_crud(t)
	local db = create_db()
	local repos = Repos(db.models)

	-- Save replay
	repos.replay_repo:saveReplay(1, "replay data here")

	-- Get replay
	local data = repos.replay_repo:getReplay(1)
	t:eq(data, "replay data here")

	-- Non-existent replay
	local missing = repos.replay_repo:getReplay(999)
	t:eq(missing, nil)

	db:close()
end

function test.user_token_lookup(t)
	local db = create_db()
	local repos = Repos(db.models)

	local bcrypt = require("bcrypt")
	local pw_bcrypt = bcrypt.digest("abc123", 10)

	repos.user_repo:createUser("TokenUser", "token@test.com", pw_bcrypt, "US")
	local user = repos.user_repo:findUserByName("TokenUser")
	repos.user_repo:partialUpdate(user.id, {token = "abc-token-123"})

	local by_token = repos.user_repo:findByToken("abc-token-123")
	t:eq(by_token.name, "TokenUser")

	db:close()
end

return test
