local SpriteRenderer = require("rizu.skin.osu.aim.OsuSpriteRenderer")

---@class rizu.skin.osu.aim.OsuFollowPointRenderer
local OsuFollowPointRenderer = {}

local spacing = 32
local base_preempt = 0.8
local base_fade = 0.4
local min_preempt = 0.45

---@param rules rizu.aim.CircleRules
---@param time number
---@param sprites rizu.skin.osu.aim.OsuAimSprites
function OsuFollowPointRenderer.draw(rules, time, sprites)
	local frames = sprites.followpoint
	if not frames or #frames == 0 then return end
	-- Fast approach rates shorten the lead-in so points do not outlive their circles.
	local timing_scale = math.min(1, rules.preempt / min_preempt)
	local preempt, fade = base_preempt * timing_scale, base_fade * timing_scale
	local frame_duration = 1 / (sprites.animation_framerate or #frames)

	local objects = rules.objects ---@type chart.osu.AimObject[]
	for index = math.max(2, rules.next_index - 1), #objects do
		local previous, target = objects[index - 1], objects[index]
		if previous.time - time > preempt then break end
		-- A new combo breaks the chain, and spinners have no position to connect.
		if target.combo_number ~= 1 and previous.kind ~= "spinner" and target.kind ~= "spinner" then
			local start_x, start_y, start_time = previous.x, previous.y, previous.time
			local slider = rules.sliders[index - 1]
			if slider then
				local timing = slider.timing
				---@type number, number
				start_x, start_y = slider.path:position(timing.spans % 2)
				start_time = timing.end_time ---@type number
			end
			local dx, dy = target.x - start_x, target.y - start_y
			local distance = math.floor(math.sqrt(dx * dx + dy * dy))
			local duration = target.time - start_time
			local rotation = math.atan2(dy, dx)
			for offset = spacing * 1.5, distance - spacing - 1e-9, spacing do
				local fraction = offset / distance
				local arrival = start_time + fraction * duration
				local age = time - (arrival - preempt)
				if age >= 0 and time < arrival + fade then
					local fade_in = math.min(1, age / fade)
					local alpha = math.min(fade_in, 1 - math.max(0, (time - arrival) / fade))
					-- Each point slides into place and shrinks as it fades in.
					local movement = 1 - (1 - fade_in) ^ 2
					local position = fraction - 0.1 * (1 - movement)
					local frame = frames[math.floor(age / frame_duration) % #frames + 1]
					SpriteRenderer.draw(frame, start_x + position * dx, start_y + position * dy,
						SpriteRenderer.getWidth(frame) * (1.5 - 0.5 * movement), alpha, rotation)
				end
			end
		end
	end
end

return OsuFollowPointRenderer
