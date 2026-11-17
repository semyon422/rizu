local LinuxFilesystem = require("fs.LinuxFilesystem")
local TestChartFactory = require("sea.chart.TestChartFactory")
local Worker = require("rizu.library.Worker")

local test = {}

---@param t testing.T
function test.session_stats_count_plays_local_firsts_and_best_ratings(t)
	local worker = Worker({} --[[@as any]], LinuxFilesystem(), ".", {} --[[@as time.ITimer]])
	worker.db:load(":memory:")
	local factory = TestChartFactory()
	local plays = worker.db.models.chartplays
	---@param id integer
	---@param hash string
	---@param rating number
	---@param created_at integer
	---@param pass boolean?
	local function play(id, hash, rating, created_at, pass)
		local chartplay = factory:createChartplay({
			id = id, hash = hash, rating = rating, rating_pp = rating * 10, created_at = created_at,
		})
		chartplay.pass = pass ~= false -- the factory turns pass = false into true
		plays:create(chartplay)
	end
	play(1, "a", 20, 100) -- before the session, still #1 on "a"
	play(2, "a", 18, 1000)
	play(3, "b", 10, 100)
	play(4, "b", 15, 1000) -- takes #1 on "b"
	play(5, "b", 14, 1001) -- same chart, counted once
	play(6, "c", 30, 1002, false) -- a fail: #1 on "c", but not the best rating

	t:tdeq(worker:getSessionStats(1000), {plays = 4, firsts = 2, best_rating = 18, best_pp = 180})
	t:tdeq(worker:getSessionStats(5000), {plays = 0, firsts = 0})
end

return test
