local class = require("class")
local flux = require("flux")

---@class sphere.JudgementView
---@operator call: sphere.JudgementView
---@field game sphere.GameController
---@field animate boolean?
---@field scale number
---@field judgements sphere.ImageAnimationView[]
---@field judgesSource rizu.ScoreSystem
local JudgementView = class()

function JudgementView:load()
	self.scoreEngine = self.game.rhythm_engine.score_engine

	local judges_source = self.scoreEngine.judgesSource
	if not judges_source then
		return
	end

	self.totalJudges = #judges_source:getJudges()
	---@cast judges_source +rizu.ScoreSystem, -rizu.IJudgesSource
	self.judgesSource = judges_source

	local base_score = self.scoreEngine:getScoreSystem("base")
	assert(base_score)
	---@cast base_score rizu.BaseScore
	self.baseScore = base_score

	self.notes = 0

	self.scale = self.scale or 1
	self.animationScale = 1
	self.rotation = 0
	self.alpha = 1
end

---@return integer?
function JudgementView:getJudge()
	local sequence = self.scoreEngine.sequence
	local sequence_len = #sequence

	if sequence_len == 0 then
		return
	end

	local slice = sequence[sequence_len][self.judgesSource:getKey()]
	return slice.last_judge
end

function JudgementView:startAnimation()
	if self.alphaTween then
		self.alphaTween:stop()
	end
	if self.scaleTween then
		self.scaleTween:stop()
	end
	if self.rotationTween then
		self.rotationTween:stop()
	end

	self.alpha = 1
	self.alphaTween = flux.to(self, 0.08, { alpha = 0 }):delay(0.36):ease("quadout")

	self.rotation = 0

	if self:getJudge() == self.totalJudges then
		self.animationScale = 1.2
		self.scaleTween = flux.to(self, 0.1, { animationScale = 1 }):ease("quadout")
		self.rotationTween = flux.to(self, 0.1, { rotation = (0.2 - math.random(1, 3) * 0.1) }):ease("quadout")
	else
		self.animationScale = 0.95
		self.scaleTween = flux.to(self, 0.08, { animationScale = 1 })
			:after(self, 0.08, { animationScale = 0.92 })
			:after(self, 0.2, {})
			:after(self, 0.08, { animationScale = 0.85 }):ease("quadin")
	end
end

---@param dt number
function JudgementView:update(dt)
	local judge = self:getJudge()

	if not judge then
		return
	end

	local image = self.judgements[judge] or self.judgements[1]
	if not image then
		return
	end

	image.color[4] = self.alpha
	image.sx = self.scale * self.animationScale
	image.sy = self.scale * self.animationScale
	image.rotation = self.rotation

	local notes = self.baseScore.hitCount + self.baseScore.missCount
	if notes == self.notes then
		return
	end
	self.notes = notes

	for _, view in ipairs(self.judgements) do
		view:setTime(math.huge)
	end
	image:setTime(0)

	if self.animate then
		self:startAnimation()
	end
end

return JudgementView
