local Events = require("rizu.api.Events")
local StoredAccuracies = require("rizu.engine.ScoreEngine.StoredAccuracies")
local Scoring = require("rizu.engine.scoring.Scoring")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")

---`rizu.api.Scores` with made-up scores, see that file for what each function does.
---@class rizu.api.fake.FakeScores : rizu.api.Events
---@operator call: rizu.api.fake.FakeScores
local FakeScores = Events + {}

function FakeScores:new()
	Events.new(self)
	self.source = "local"
	self.items = {}
	self.chart_id = 0
end

---The fake game calls this when another chart is selected.
---@param chart rizu.api.Chart?
function FakeScores:setChart(chart)
	self.chart_id = chart and chart.chartfile_id or 0
	self:refresh()
end

function FakeScores:refresh()
	self.items = {}
	self.selected = nil
	local online = self.source == "online"
	for i = 1, self.chart_id % 6 do
		self.items[i] = {
			id = self.chart_id * 10 + i,
			score = 9900 - i * 350, accuracy = 0.012 + i * 0.004, rating = 20 - i,
			rate = i == 3 and 1.1 or 1, const = i == 2, modifiers = {}, pause_count = 0, miss_count = i * 2,
			created_at = os.time() - i * 86400 * 3,
			user_name = online and ("Player %d"):format(i) or nil,
		}
	end
	self:emit("scores_changed", false)
end

function FakeScores:getCount() return #self.items end
function FakeScores:get(index) return self.items[index] end
function FakeScores:isLoading() return false end
function FakeScores:getSource() return self.source end

function FakeScores:setSource(source)
	self.source = source
	self:refresh()
end

function FakeScores:select(index) self.selected = self.items[index] or self.selected end
function FakeScores:getSelected() return self.selected end

function FakeScores:getAccuracySystems() return {"auto", "osuod:9:1", "etternaj:4"} end
function FakeScores:getSelectedAccuracySystem() return self.accuracy_system or "auto" end

function FakeScores:setSelectedAccuracySystem(token)
	self.accuracy_system = token
	self:refresh()
end

---@param chart rizu.api.Chart?
---@param token string?
function FakeScores:getAccuracySystem(chart, token)
	local auto = chart and chart.format
		and Scoring(TimingSystems.getAuto(chart.chartmeta_timings, chart.format))
	return StoredAccuracies.getScoring(token or self:getSelectedAccuracySystem(), auto)
end

---@param score rizu.api.Score
function FakeScores:getAccuracy(score)
	if self.source ~= "local" then return end
	local offset = ({["osuod:9:1"] = -150, ["etternaj:4"] = -400})[self:getSelectedAccuracySystem()] or 0
	return ("%0.02f%%"):format((score.score + offset) / 100)
end

---There is no game to replay the score: `rizu.api.fake.FakeResult` shows the same play for every score.
function FakeScores:loadSelectedResult(f) f(self.selected ~= nil) end

return FakeScores
