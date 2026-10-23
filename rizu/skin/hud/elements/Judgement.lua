local HudElement = require("rizu.skin.hud.HudElement")
local Animations = require("rizu.skin.hud.Animations")
local TextureImage = require("rizu.skin.TextureImage")

---Shows the latest judgement. Judges map to six grades by their place in the judging system:
---1 is the best hit and 6 is the miss, the last judge, whatever the system calls it.
---@class rizu.skin.hud.elements.Judgement : rizu.skin.hud.HudElement
---@operator call: rizu.skin.hud.elements.Judgement
---@field judgement_state rizu.skin.hud.Animations.JudgementState
---@field frames rizu.skin.SkinTextures.Image[]
---@field judgement_count integer
local Judgement = HudElement + {}

Judgement.label = "Judgement"

-- Judge names of every judging system, for skins with a sprite per name.
Judgement.judge_names = {"marvelous", "perfect", "pgreat", "great", "good", "ok", "okay", "bad", "meh", "boo", "poor", "miss"}

-- Tints of grades when `colored` is on.
local colors = {
	{0, 1, 1, 1}, -- cyan
	{1, 1, 0, 1}, -- yellow
	{0, 1, 0, 1}, -- green
	{0.2, 0.4, 1, 1}, -- blue
	{1, 0, 1, 1}, -- magenta
	{1, 0, 0, 1}, -- red
}
local white = {1, 1, 1, 1}
local FRAME_RATE = 20

Judgement.fields = {
	{key = "texture_1", label = "Best texture", type = "texture", default = "mania-hit300g"},
	{key = "texture_2", label = "2nd texture", type = "texture", default = "mania-hit300"},
	{key = "texture_3", label = "3rd texture", type = "texture", default = "mania-hit200"},
	{key = "texture_4", label = "4th texture", type = "texture", default = "mania-hit100"},
	{key = "texture_5", label = "5th texture", type = "texture", default = "mania-hit50"},
	{key = "texture_6", label = "Miss texture", type = "texture", default = "mania-hit0"},
	-- When set, a judge named "great" first looks for `<name_prefix>great`.
	{key = "name_prefix", label = "Texture per judge name", type = "text", default = ""},
	{key = "colored", label = "Tint by grade", type = "checkbox", default = false},
	{key = "animation", label = "Animation", type = "dropdown", options = Animations.names(Animations.judgement),
		default = "none"},
}

---@param values {[string]: any}?
---@param textures rizu.skin.SkinTextures
function Judgement:new(values, textures)
	self.frames = {}
	self.judgement_count = 0
	self.judgement_state = {elapsed = math.huge, grade = 1, start_alpha = 0, rotation = 0}
	HudElement.new(self, values, textures)
end

---@return rizu.skin.SkinTextures.Asset[]
function Judgement:getAssets()
	local assets = {} ---@type rizu.skin.SkinTextures.Asset[]
	for grade = 1, 6 do
		assets[#assets + 1] = {name = self.values["texture_" .. grade] --[[@as string]], animation = true,
			group = HudElement.group}
	end
	local prefix = self.values.name_prefix --[[@as string]]
	if prefix ~= "" then
		for _, name in ipairs(Judgement.judge_names) do
			assets[#assets + 1] = {name = prefix .. name, animation = true, group = HudElement.group}
		end
	end
	return assets
end

---@param context rizu.api.GameApi
function Judgement:load(context)
	HudElement.load(self, context)
	self.frames = {}
	self.judgement_count = 0
	self.judgement_state.elapsed = math.huge
end

---@param context rizu.api.GameApi?
function Judgement:unload(context)
	self.frames = {}
	HudElement.unload(self, context)
end

---@param judge integer Index in the judge names, negative counts from the end.
---@param count integer How many judges there are.
---@return integer grade
function Judgement.getGrade(judge, count)
	if judge < 0 then judge = count + judge + 1 end
	if judge >= count then return 6 end
	return math.max(1, math.min(judge, 5))
end

---@return rizu.skin.hud.Animations.Judgement
function Judgement:getAnimationPreset()
	return Animations.judgement[self.values.animation]
end

---@return number
function Judgement:getAlpha()
	local state = self.judgement_state
	local preset = self:getAnimationPreset()
	if not self.frames[1] or state.elapsed >= preset.duration then return 0 end
	local _, _, alpha = preset.get(state)
	return alpha
end

---@param name string Judge name.
---@param grade integer
function Judgement:show(name, grade)
	local prefix = self.values.name_prefix --[[@as string]]
	local frames = prefix ~= "" and self:getAnimation(prefix .. name:lower()) or {}
	if not frames[1] then frames = self:getAnimation(self.values["texture_" .. grade] --[[@as string]]) end
	if not frames[1] then return end
	local state = self.judgement_state
	state.start_alpha = self:getAlpha()
	state.elapsed, state.grade = 0, grade
	local preset = self:getAnimationPreset()
	if preset.trigger then preset.trigger(state) end
	self.frames = frames
	self.width, self.height = TextureImage.dimensions(frames[1])
end

---@param dt number
---@param context rizu.api.GameApi
function Judgement:update(dt, context)
	local gameplay = context.gameplay
	self.judgement_state.elapsed = self.judgement_state.elapsed + math.max(0, dt)
	local count = gameplay:getJudgementCount()
	if count < self.judgement_count then self.judgement_count = 0 end -- retry
	if count == self.judgement_count then return end
	local names = gameplay:getJudgeNames()
	for i = self.judgement_count + 1, count do
		local _, _, judge = gameplay:getJudgement(i)
		if judge and #names > 0 then
			local grade = Judgement.getGrade(judge, #names)
			self:show(names[judge < 0 and #names + judge + 1 or judge] or "", grade)
		end
	end
	self.judgement_count = count
end

function Judgement:draw()
	local state = self.judgement_state
	local preset = self:getAnimationPreset()
	local frames = self.frames
	if not frames[1] or state.elapsed >= preset.duration then return end
	local scale, rotation, alpha = preset.get(state)
	local color = self.values.colored and colors[state.grade] or white
	HudElement.setColor(color, math.max(0, alpha))
	local frame = frames[math.min(#frames, math.floor(state.elapsed * FRAME_RATE) + 1)]
	local width, height = TextureImage.dimensions(frame)
	TextureImage.drawDirect(frame, self.width / 2, self.height / 2, rotation, scale, scale, width / 2, height / 2)
end

return Judgement
