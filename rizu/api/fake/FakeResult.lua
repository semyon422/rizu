local class = require("class")

---`rizu.api.Result` with one made-up play, see that file for what each function does.
---@class rizu.api.fake.FakeResult
---@operator call: rizu.api.fake.FakeResult
local FakeResult = class()

local judge_names = {"perfect", "great", "good", "ok", "meh", "miss"}
-- Seconds. A hit gets the first judge whose window it fits.
local judge_windows = {0.016, 0.04, 0.073, 0.103, 0.127}
local hit_count = 600

function FakeResult:new()
	self.hits = {}
	self.judge_counts = {0, 0, 0, 0, 0, 0}
	local seed, sum = 1, 0
	local function random()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	for i = 1, hit_count do
		-- Three random numbers make a bell around zero, like real hits.
		local delta = (random() + random() + random() - 1.5) * 0.09
		local miss = random() < 0.02
		local judge = #judge_names
		for index, window in ipairs(judge_windows) do
			if not miss and math.abs(delta) <= window then
				judge = index
				break
			end
		end
		miss = judge == #judge_names
		sum = sum + (miss and 0 or delta)
		self.judge_counts[judge] = self.judge_counts[judge] + 1
		self.hits[i] = {
			time = i * 0.2,
			kind = miss and "miss" or "hit",
			delta = miss and 0 or delta,
			judge = judge,
			accuracy = 0.021,
			mean = sum / i,
			normalscore = 0.9,
		}
	end
end

function FakeResult:getChartdiff()
	return {
		enps_diff = 14.2, osu_diff = 5.1, msd_diff = 21.4, user_diff = 14,
		notes_count = hit_count, judges_count = hit_count, long_notes_ratio = 0,
	}
end

function FakeResult:getRate() return 1 end
function FakeResult:getMutators() return {} end
function FakeResult:hasScore() return true end
function FakeResult:getRescoreSystems() return {"sphere", "osuod", "etternaj", "quaver", "bmsrank", "iidx"} end
function FakeResult:rescore() return nil, "There is no game in the preview." end

function FakeResult:getJudging()
	return {
		timings = {name = "osuod", data = 8},
		subtimings = {name = "scorev", data = 1},
		getJudgeNames = function() return judge_names end,
	}
end

function FakeResult:getAccuracy() return 0.9652, "96.52%" end
function FakeResult:getScore() return 903714, "903714" end
function FakeResult:getJudgeCounts() return self.judge_counts end
function FakeResult:getMaxCombo() return 214, hit_count end
function FakeResult:getNormalscoreText() return "21.00ms" end
function FakeResult:getPauseCount() return 0 end
function FakeResult:getMissCounts() return {left = 3, center = 0, right = 5, scratch = 1} end
function FakeResult:getHitWindow() return -0.127, 0.127 end
function FakeResult:getHits() return self.hits end

---There is no gameplay to load, so both always fail.
function FakeResult:retry(f) f(false) end
function FakeResult:watch(f) f(false) end
function FakeResult:close() end

return FakeResult
