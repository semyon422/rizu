local HudElement = require("rizu.skin.hud.HudElement")
local Judgement = require("rizu.skin.hud.elements.Judgement")
local TextureImage = require("rizu.skin.TextureImage")

local lg = love.graphics

local ICON_SIZE = 9 * 1.6
local ICON_GAP = 1.6
local ICON_COUNT = 14
local FADE_DELAY = 4
local FADE_RATE = 2.4
local ERROR_SCALE = 1.6
local BAR_HEIGHT = 3 * ERROR_SCALE
local BACKGROUND_HEIGHT = BAR_HEIGHT * 4
local TIMING_HEIGHT = BACKGROUND_HEIGHT + 8
local POINT_FADE = 10
local POINT_COUNT = 64
local DEFAULT_WINDOWS = {0.016, 0.064, 0.097, 0.127, 0.151, 0.188}
local GRADE_COLORS = {
	{0.20, 0.74, 0.91}, {0.34, 0.89, 0.08}, {0.85, 0.68, 0.27},
	{0.12, 0.41, 0.78}, {0.43, 0.47, 0.53}, {1, 0.035, 0.035},
}
local ERROR_COLORS = {
	{0.20, 0.74, 0.91}, -- 300
	{0.34, 0.89, 0.08}, -- 100
	{0.85, 0.68, 0.27}, -- 50
	{1, 0.035, 0.035}, -- miss
}

---@class rizu.skin.hud.elements.OsuHitError.Point
---@field position number
---@field color number[]
---@field age number

---"judgements" shows the colors of the latest judgements in a row, "timing" shows how early or
---late the hits were on a bar of the judge windows.
---@class rizu.skin.hud.elements.OsuHitError : rizu.skin.hud.HudElement
---@operator call: rizu.skin.hud.elements.OsuHitError
---@field judgement_count integer
---@field since_hit number
---@field icon_index integer
---@field icons {color: number[], alpha: number}[]
---@field windows number[]
---@field range number
---@field target_position number
---@field position number
---@field point_index integer
---@field points rizu.skin.hud.elements.OsuHitError.Point[]
---@field alpha number
---@field arrow rizu.skin.SkinTextures.Image?
local OsuHitError = HudElement + {}

OsuHitError.label = "osu!stable hit error meter"
OsuHitError.defaults = {anchor = "bottom", origin = "bottom"}
OsuHitError.fields = {
	{key = "mode", label = "Mode", type = "segmented", options = {"judgements", "timing"}, default = "judgements",
		format = function(value) return value == "timing" and "Timing error" or "Judgement history" end},
	{key = "arrow", label = "Arrow texture", type = "texture", default = ""},
}

---@param values {[string]: any}?
---@param textures rizu.skin.SkinTextures
function OsuHitError:new(values, textures)
	self.icons = {}
	for i = 1, ICON_COUNT do self.icons[i] = {color = GRADE_COLORS[1], alpha = 0} end
	self.points = {}
	for i = 1, POINT_COUNT do self.points[i] = {position = 0, color = ERROR_COLORS[1], age = math.huge} end
	self.windows = DEFAULT_WINDOWS
	self.range = DEFAULT_WINDOWS[5]
	HudElement.new(self, values, textures)
	self:reset()
end

function OsuHitError:reset()
	self.judgement_count = 0
	self.since_hit = math.huge
	self.icon_index = 0
	self.point_index = 0
	self.alpha = 0
	for _, icon in ipairs(self.icons) do icon.alpha = 0 end
	for _, point in ipairs(self.points) do point.age = math.huge end
	self.target_position = self.width / 2
	self.position = self.target_position
end

function OsuHitError:applyValues()
	HudElement.applyValues(self)
	if self.values.mode == "timing" then
		self.width, self.height = self.range * 1000 * ERROR_SCALE, TIMING_HEIGHT
	else
		self.width, self.height = ICON_COUNT * (ICON_SIZE + ICON_GAP), ICON_SIZE
	end
end

---@return rizu.skin.SkinTextures.Asset[]
function OsuHitError:getAssets()
	return {{name = self.values.arrow --[[@as string]], group = HudElement.group}}
end

---@param context rizu.api.GameApi
function OsuHitError:load(context)
	HudElement.load(self, context)
	self.arrow = self:getTexture(self.values.arrow --[[@as string]])
	self:setWindows(context.gameplay:getJudgeWindows())
	self:reset()
end

---@param context rizu.api.GameApi?
function OsuHitError:unload(context)
	self.arrow = nil
	HudElement.unload(self, context)
end

---@param windows number[]? Seconds from the note, one per judge from the best.
function OsuHitError:setWindows(windows)
	local filled = {} ---@type number[]
	for i, default in ipairs(DEFAULT_WINDOWS) do
		local value = windows and #windows > 0 and tonumber(windows[math.min(i, #windows)])
		filled[i] = value and value > 0 and value < math.huge and value or default
	end
	self.windows = filled
	self.range = filled[5]
	self:applyValues()
end

---@param delta number Seconds off the note, negative is early.
function OsuHitError:addError(delta)
	local range, windows = self.range, self.windows
	local position = self.width / 2 + math.max(-range, math.min(range, delta)) / range * self.width / 2
	self.target_position = position
	local error = math.abs(delta)
	local color = error <= windows[2] and ERROR_COLORS[1] or error <= windows[4] and ERROR_COLORS[2]
		or error <= windows[5] and ERROR_COLORS[3] or ERROR_COLORS[4]
	self.point_index = self.point_index % #self.points + 1
	local point = self.points[self.point_index]
	point.position, point.color, point.age = position, color, 0
	self.since_hit, self.alpha = 0, 1
end

---@param grade integer
function OsuHitError:addJudgement(grade)
	for _, icon in ipairs(self.icons) do icon.alpha = math.max(0, icon.alpha - 0.08) end
	self.icon_index = self.icon_index % #self.icons + 1
	local icon = self.icons[self.icon_index]
	icon.color, icon.alpha = GRADE_COLORS[grade], 1
	self.since_hit = 0
end

---@param dt number
---@param context rizu.api.GameApi
function OsuHitError:update(dt, context)
	local gameplay = context.gameplay
	local count = gameplay:getJudgementCount()
	if count < self.judgement_count then self:reset() end -- retry
	local timing = self.values.mode == "timing"
	local judge_count = #gameplay:getJudgeNames()
	for i = self.judgement_count + 1, count do
		local kind, delta, judge = gameplay:getJudgement(i)
		if timing then
			if kind == "hit" then self:addError(delta) end
		elseif judge and judge_count > 0 then
			self:addJudgement(Judgement.getGrade(judge, judge_count))
		end
	end
	self.judgement_count = count

	local elapsed = math.max(0, dt)
	self.since_hit = self.since_hit + elapsed
	local fade = self.since_hit > FADE_DELAY and math.max(0, 1 - elapsed * FADE_RATE) or 1
	if timing then
		if self.alpha > 0 then
			self.position = self.position + (self.target_position - self.position) * math.min(1, elapsed / 0.8)
		end
		for _, point in ipairs(self.points) do point.age = point.age + elapsed end
		self.alpha = self.alpha * fade
	else
		for _, icon in ipairs(self.icons) do icon.alpha = icon.alpha * fade end
	end
end

function OsuHitError:drawTiming()
	local alpha = self.alpha
	if alpha <= 0 then return end
	local width, center, windows = self.width, self.width / 2, self.windows
	local bar_center = self.height - 2
	local top = bar_center - BACKGROUND_HEIGHT / 2

	lg.setColor(0, 0, 0, 0.6 * alpha)
	lg.rectangle("fill", 0, top, width, BACKGROUND_HEIGHT)
	for i, window in ipairs({windows[5], windows[4], windows[2]}) do
		local color = ERROR_COLORS[4 - i]
		local band = window / self.range * width
		lg.setColor(color[1], color[2], color[3], alpha)
		lg.rectangle("fill", center - band / 2, bar_center - BAR_HEIGHT / 2, band, BAR_HEIGHT)
	end

	local mode, alpha_mode = lg.getBlendMode()
	lg.setBlendMode("add", "alphamultiply")
	for _, point in ipairs(self.points) do
		if point.age < POINT_FADE then
			local color = point.color
			lg.setColor(color[1], color[2], color[3], alpha * 0.4 * (1 - point.age / POINT_FADE))
			lg.rectangle("fill", point.position - 1.5, top, 3, BACKGROUND_HEIGHT)
		end
	end
	lg.setColor(1, 1, 1, alpha)
	lg.rectangle("fill", center - 0.75, top, 1.5, BACKGROUND_HEIGHT)
	lg.setBlendMode(mode, alpha_mode)

	local arrow = self.arrow
	if arrow then
		local arrow_width, arrow_height = TextureImage.dimensions(arrow)
		local scale = 0.6 * 480 / 768
		lg.setColor(1, 1, 1, alpha)
		TextureImage.draw(arrow, self.position, bar_center - 3, 0, scale, scale, arrow_width / 2, arrow_height)
	end
end

function OsuHitError:draw()
	if self.values.mode == "timing" then return self:drawTiming() end
	local mode, alpha_mode = lg.getBlendMode()
	lg.setBlendMode("add", "alphamultiply")
	local x = 0
	for _, icon in ipairs(self.icons) do
		if icon.alpha > 0 then
			lg.setColor(icon.color[1], icon.color[2], icon.color[3], icon.alpha * 0.8)
			lg.rectangle("fill", x, 0, ICON_SIZE, ICON_SIZE)
		end
		x = x + ICON_SIZE + ICON_GAP
	end
	lg.setBlendMode(mode, alpha_mode)
end

return OsuHitError
