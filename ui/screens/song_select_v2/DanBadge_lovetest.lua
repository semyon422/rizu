local DanBadge = require("ui.screens.song_select_v2.DanBadge")
local Resources = require("ui.Resources")

local test = {}
local lg = love.graphics

---@param t testing.T
function test.shows_an_icon_with_a_mark_or_the_name_as_text(t)
	if not lg.isActive() then assert(love.window.setMode(1000, 720)) end

	Resources.load()

	local badge = DanBadge()
	t:assert(not badge.visible)

	badge:setDan("Beta+")
	t:assert(badge.visible)
	t:assert(badge.icon and badge.mark_icon, "icon and plus mark")
	t:assert(badge:getAuthoredWidth() > DanBadge.HEIGHT * badge.icon:getWidth() / badge.icon:getHeight())

	badge:setDan("Gamma")
	t:assert(badge.icon and not badge.mark_icon)

	badge:setDan("Omega-")
	t:assert(not badge.icon, "a dan without an icon is written out")
	t:assert(badge:getAuthoredWidth() > 0)

	for _, dan in ipairs({"Beta+", "Gamma", "3rd-", "Intro", "Theta+", "10th", "Omega-"}) do
		badge:setDan(dan)
		lg.clear()
		badge:draw()
		lg.present()
	end

	for _, dan in ipairs({"Intro", "1st", "8th", "Theta+"}) do
		badge:setDan(dan)
		t:assert(badge.icon, dan)
	end

	-- Rare: from Gamma on it glitches once every 1-3 seconds, never below.
	for dan, glitches in pairs({Beta = false, ["9th"] = false, Gamma = true, Theta = true}) do
		badge:setDan(dan)
		local frames_glitching, started = 0, 0
		for _ = 1, 60 * 30 do
			local was = badge.glitch_left > 0
			badge:update(1 / 60)
			if badge.glitch_left > 0 then
				frames_glitching = frames_glitching + 1
				if not was then started = started + 1 end
				lg.clear()
				badge:draw()
				lg.present()
			end
		end
		if glitches then
			t:assert(started >= 8 and started <= 30, dan .. " glitched " .. started .. " times in 30s")
			t:assert(frames_glitching < 60 * 30 / 3, dan .. " glitches only for short moments")
		else
			t:eq(started, 0, dan)
		end
	end

	badge:setDan(nil)
	t:assert(not badge.visible)
end

return test
