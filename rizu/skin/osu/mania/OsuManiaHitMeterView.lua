local View = require("rizu.skin.View")

local lg = love.graphics
local ICON_SIZE = 9 * 1.6
local ICON_GAP = 1.6
local FADE_DELAY = 4
local FADE_RATE = 2.4
local ERROR_SCALE = 1.6
local ERROR_BAR_HEIGHT = 3 * ERROR_SCALE
local ERROR_BACKGROUND_HEIGHT = ERROR_BAR_HEIGHT * 4
local ERROR_VIEW_HEIGHT = ERROR_BACKGROUND_HEIGHT + 8
local ERROR_POINT_FADE = 10
local MAX_ERROR_POINTS = 64
local DEFAULT_ERROR_WINDOWS = {0.016, 0.064, 0.097, 0.127, 0.151, 0.188}
local SPRITE_SCALE = 480 / 768
local ERROR_ARROW_SCALE = 0.6 * SPRITE_SCALE
local COLORS = {
	{0.20, 0.74, 0.91}, {0.34, 0.89, 0.08}, {0.85, 0.68, 0.27},
	{0.12, 0.41, 0.78}, {0.43, 0.47, 0.53}, {1, 0.035, 0.035},
}
local ERROR_COLORS = {
	{0.20, 0.74, 0.91}, -- 300
	{0.34, 0.89, 0.08}, -- 100
	{0.85, 0.68, 0.27}, -- 50
	{1, 0.035, 0.035}, -- miss
}

---@class rizu.skin.osu.mania.OsuManiaHitMeterView.ErrorPoint
---@field position number
---@field color number[]
---@field age number

---@class rizu.skin.osu.mania.OsuManiaHitMeterView : rizu.skin.View
---@operator call: rizu.skin.osu.mania.OsuManiaHitMeterView
---@field sequence_index integer
---@field score_engine rizu.ScoreEngine?
---@field last_hit_time number
---@field icon_index integer
---@field icons {color: number[], alpha: number}[]
---@field mode "colour"|"error"
---@field error_mode boolean
---@field error_windows number[]
---@field error_range number
---@field target_position number
---@field floating_position number
---@field point_index integer
---@field error_points rizu.skin.osu.mania.OsuManiaHitMeterView.ErrorPoint[]
---@field meter_alpha number
---@field graphics rizu.skin.osu.mania.OsuManiaSkinGraphics?
---@field arrow_image love.Image?
local OsuManiaHitMeterView = View + {}
---@return number[]
local function get_error_windows(source)
	local source_data = source --[[@as any]]
	local source_windows = source_data and source_data.judge_windows
		and source_data.judge_windows.windows
	local windows = {}
	if type(source_windows) == "table" and #source_windows > 0 then
		for index = 1, #DEFAULT_ERROR_WINDOWS do
			local value = tonumber(source_windows[math.min(index, #source_windows)])
			if value and value > 0 and value < math.huge then
				windows[index] = value
			else
				windows[index] = DEFAULT_ERROR_WINDOWS[index]
			end
		end
	else
		for index, value in ipairs(DEFAULT_ERROR_WINDOWS) do windows[index] = value end
	end
	return windows
end

---@param value number
---@return boolean
local function is_finite(value)
	return value == value and value ~= math.huge and value ~= -math.huge
end

---@param judge integer
---@param source rizu.IJudgesSource
---@return integer?
local function get_grade(judge, source)
	local names = source.getJudgeNames and source:getJudgeNames()
	if judge < 0 and names then judge = #names + judge + 1 end
	local name = names and names[judge]
	if name then
		name = name:lower()
		if name:find("miss", 1, true) or name:find("poor", 1, true) or name == "0" then
			return 6
		elseif name:find("perfect", 1, true) or name:find("marvelous", 1, true) or name == "pgreat" then
			return 1
		elseif name:find("great", 1, true) then
			return 2
		elseif name:find("good", 1, true) or name == "200" then
			return 3
		elseif name == "ok" or name == "100" or name == "bad" then
			return 4
		elseif name == "meh" or name == "50" or name == "boo" then
			return 5
		end
	end
	if type(judge) == "number" and judge >= 1 and judge <= 6 then return judge end
end

---@param graphics rizu.skin.osu.mania.OsuManiaSkinGraphics?
function OsuManiaHitMeterView:new(graphics)
	self.graphics = graphics
	self.arrow_image = nil
	self.sequence_index = 0
	self.score_engine = nil
	self.last_hit_time = -math.huge
	self.icon_index = 0
	self.icons = {}
	for _ = 1, 14 do self.icons[#self.icons + 1] = {color = COLORS[1], alpha = 0} end

	self.mode = "colour"
	self.error_mode = false
	self.error_windows = {}
	for index, value in ipairs(DEFAULT_ERROR_WINDOWS) do self.error_windows[index] = value end
	self.error_range = DEFAULT_ERROR_WINDOWS[#DEFAULT_ERROR_WINDOWS]
	self.target_position = self.width and self.width / 2 or self.error_range * 1000 * ERROR_SCALE / 2
	self.floating_position = self.target_position
	self.point_index = 0
	self.error_points = {}
	for index = 1, MAX_ERROR_POINTS do
		self.error_points[index] = {position = self.target_position, color = ERROR_COLORS[1], age = math.huge}
	end
	self.meter_alpha = 0

	View.new(self, {anchor = "bottom", origin = "bottom", x = 0, y = -4,
		width = #self.icons * (ICON_SIZE + ICON_GAP), height = ICON_SIZE})
end

function OsuManiaHitMeterView:setMode(mode)
	mode = mode == 1 and "error" or "colour"
	if mode == self.mode then return end
	self.mode = mode
	self.error_mode = mode == "error"
	self.error_range = self.error_mode and nil or self.error_range
	self.last_hit_time = -math.huge
	self.meter_alpha = 0
	self.point_index = 0
	for _, icon in ipairs(self.icons) do icon.alpha = 0 end
	for _, point in ipairs(self.error_points) do point.age = math.huge end
	if self.error_mode then
		self.width = DEFAULT_ERROR_WINDOWS[math.min(5, #DEFAULT_ERROR_WINDOWS)] * 1000 * ERROR_SCALE
		self.height = ERROR_VIEW_HEIGHT
	else
		self.width = #self.icons * (ICON_SIZE + ICON_GAP)
		self.height = ICON_SIZE
	end
end

---@param game sphere.GameController
function OsuManiaHitMeterView:load(game)
	View.load(self, game)
	local graphics = self.graphics
	local frames = graphics and graphics.getFallbackFrames
		and graphics:getFallbackFrames("editor-rate-arrow") or nil
	self.arrow_image = frames and frames[1] or nil
	self.sequence_index = 0
	self.score_engine = nil
	self.error_range = nil
	self.last_hit_time = -math.huge
	self.icon_index = 0
	self.point_index = 0
	self.meter_alpha = 0
	for _, icon in ipairs(self.icons) do icon.alpha = 0 end
	for _, point in ipairs(self.error_points) do point.age = math.huge end
end

---@param source rizu.IJudgesSource?
function OsuManiaHitMeterView:updateErrorLayout(source)
	self.error_windows = get_error_windows(source)
	self.error_range = self.error_windows[math.min(5, #self.error_windows)]
	self.width = self.error_range * 1000 * ERROR_SCALE
	self.target_position = self.width / 2
	self.floating_position = self.target_position
end

---@param delta number
function OsuManiaHitMeterView:addError(delta)
	local range = self.error_range
	local clamped_delta = math.max(-range, math.min(range, delta))
	local position = self.width / 2 + clamped_delta / range * (self.width / 2)
	self.target_position = position

	local absolute_delta = math.abs(delta)
	local windows = self.error_windows
	local color
	if absolute_delta <= windows[math.min(2, #windows)] then
		color = ERROR_COLORS[1]
	elseif absolute_delta <= windows[math.min(4, #windows)] then
		color = ERROR_COLORS[2]
	elseif absolute_delta <= windows[math.min(5, #windows)] then
		color = ERROR_COLORS[3]
	else
		color = ERROR_COLORS[4]
	end

	self.point_index = self.point_index % #self.error_points + 1
	local point = self.error_points[self.point_index]
	point.position = position
	point.color = color
	point.age = 0
	self.last_hit_time = 0
	self.meter_alpha = 1
end

---@param dt number
---@param game sphere.GameController
function OsuManiaHitMeterView:update(dt, game)
	local engine = game and game.rhythm_engine
	local score_engine = engine and engine.score_engine
	local sequence = score_engine and score_engine.sequence
	local source = score_engine and score_engine.judgesSource
	if score_engine ~= self.score_engine then
		self.score_engine = score_engine
		self.sequence_index = 0
		self.last_hit_time = -math.huge
		self.meter_alpha = 0
		self.point_index = 0
		for _, icon in ipairs(self.icons) do icon.alpha = 0 end
		for _, point in ipairs(self.error_points) do point.age = math.huge end
		if self.error_mode and not self.error_range then
			self:updateErrorLayout(source)
		end
	elseif self.error_mode and not self.error_range then
		self:updateErrorLayout(source)
	end

	local latest_index = sequence and #sequence or 0
	if latest_index < self.sequence_index then
		self.sequence_index = 0
	end
	if sequence and source then
		if self.error_mode and not self.error_range then
			self:updateErrorLayout(source)
		end
		for index = self.sequence_index + 1, latest_index do
			local slice = sequence[index]
			local judgement = slice and slice[source:getKey()]
			local judge = judgement and (judgement.visual_judge or judgement.judge_index or judgement.last_judge)
			if judge then
				local grade = get_grade(judge, source)
				if self.error_mode then
					local misc = slice.misc
					local delta = misc and tonumber(misc.deltaTime)
					if delta and is_finite(delta) then self:addError(delta) end
				elseif grade then
					for _, icon in ipairs(self.icons) do icon.alpha = math.max(0, icon.alpha - 0.08) end
					self.icon_index = self.icon_index % #self.icons + 1
					local icon = self.icons[self.icon_index]
					icon.color = COLORS[grade]
					icon.alpha = 1
					self.last_hit_time = 0
				end
			end
		end
		self.sequence_index = latest_index
	end

	local elapsed = math.max(0, dt)
	if self.error_mode and self.meter_alpha > 0 then
		local movement = math.min(1, elapsed / 0.8)
		self.floating_position = self.floating_position
			+ (self.target_position - self.floating_position) * movement
	end
	self.last_hit_time = self.last_hit_time + elapsed
	if self.error_mode then
		for _, point in ipairs(self.error_points) do
			if point.age < math.huge then point.age = point.age + elapsed end
		end
		if self.last_hit_time > FADE_DELAY then
			self.meter_alpha = self.meter_alpha * math.max(0, 1 - elapsed * FADE_RATE)
		end
	else
		if self.last_hit_time > FADE_DELAY then
			local alpha = math.max(0, 1 - elapsed * FADE_RATE)
			for _, icon in ipairs(self.icons) do icon.alpha = icon.alpha * alpha end
		end
	end
end

function OsuManiaHitMeterView:drawErrorMeter()
	if self.meter_alpha <= 0 then return end
	if not self.arrow_image and self.graphics then
		local frames = self.graphics:getFallbackFrames("editor-rate-arrow")
		self.arrow_image = frames[1]
	end
	local alpha = self.meter_alpha
	local center = self.width / 2
	local bar_center = self.height - 2
	local background_top = bar_center - ERROR_BACKGROUND_HEIGHT / 2
	local windows = self.error_windows

	lg.setColor(0, 0, 0, 0.6 * alpha)
	lg.rectangle("fill", 0, background_top, self.width, ERROR_BACKGROUND_HEIGHT)

	local bands = {
		{windows[math.min(5, #windows)], ERROR_COLORS[3]},
		{windows[math.min(4, #windows)], ERROR_COLORS[2]},
		{windows[math.min(2, #windows)], ERROR_COLORS[1]},
	}
	for _, band in ipairs(bands) do
		local band_width = band[1] / self.error_range * self.width
		lg.setColor(band[2][1], band[2][2], band[2][3], alpha)
		lg.rectangle("fill", center - band_width / 2, bar_center - ERROR_BAR_HEIGHT / 2,
			band_width, ERROR_BAR_HEIGHT)
	end

	local previous_mode, previous_alpha = lg.getBlendMode()
	lg.setBlendMode("add", "alphamultiply")
	for _, point in ipairs(self.error_points) do
		if point.age < ERROR_POINT_FADE then
			local point_alpha = alpha * 0.4 * (1 - point.age / ERROR_POINT_FADE)
			lg.setColor(point.color[1], point.color[2], point.color[3], point_alpha)
			lg.rectangle("fill", point.position - 1.5, background_top, 3, ERROR_BACKGROUND_HEIGHT)
		end
	end
	lg.setColor(1, 1, 1, alpha)
	lg.rectangle("fill", center - 0.75, background_top, 1.5, ERROR_BACKGROUND_HEIGHT)
	lg.setBlendMode(previous_mode, previous_alpha)

	local arrow_y = bar_center - 3
	if self.arrow_image then
		local width, height = self.arrow_image:getDimensions()
		lg.setColor(1, 1, 1, alpha)
		lg.draw(self.arrow_image, self.floating_position, arrow_y,
			0, ERROR_ARROW_SCALE, ERROR_ARROW_SCALE, width / 2, height)
	end
end

function OsuManiaHitMeterView:draw()
	if self.error_mode then
		self:drawErrorMeter()
		return
	end
	local x = 0
	local previous_mode, previous_alpha = lg.getBlendMode()
	lg.setBlendMode("add", "alphamultiply")
	for _, icon in ipairs(self.icons) do
		if icon.alpha > 0 then
			lg.setColor(icon.color[1], icon.color[2], icon.color[3], icon.alpha * 0.8)
			lg.rectangle("fill", x, 0, ICON_SIZE, ICON_SIZE)
		end
		x = x + ICON_SIZE + ICON_GAP
	end
	lg.setBlendMode(previous_mode, previous_alpha)
end

return OsuManiaHitMeterView
