local OsuTaikoRenderer = require("rizu.skin.osu.OsuTaikoRenderer")
local test = {}

---@param t testing.T
function test.uses_height_scaled_640_by_480_taiko_reference_field(t)
	local renderer = OsuTaikoRenderer({fs = {}})
	local scale, field_width = renderer:getField(1920, 1080)
	t:eq(scale, 2.25)
	t:eq(field_width, 1920 / 2.25)

	scale, field_width = renderer:getField(640, 480)
	t:eq(scale, 1)
	t:eq(field_width, 640)

	local x, y = renderer:getNotePosition(10, 10, field_width, 1.5)
	t:eq(x, 160)
	t:eq(y, 197)
	x, y = renderer:getNotePosition(11.5, 10, field_width, 1.5)
	t:eq(x, 760)
	t:eq(y, 197)
end

---@param t testing.T
function test.uses_stable_taiko_gamefield_sprite_ratio(t)
	local renderer = OsuTaikoRenderer({fs = {}})
	-- HitObjectManagerTaiko derives its 128px texture scale from the 512px
	-- gamefield's forced CS=-3 sprite diameter.
	local sprite_ratio = (512 / 8 * (1 - 0.7 * -3 / 5)) / 128
	t:aeq(renderer:getGamefieldSpriteScale(), sprite_ratio, 1e-9)
	t:aeq(113 * renderer:getNoteSpriteScale(true), 80.23, 1e-9)
	t:aeq(113 * renderer:getNoteSpriteScale(false), 52.1495, 1e-9)
	t:aeq(200 * renderer:getWindowSpriteScale(), 125, 1e-9)
	t:aeq(renderer:getStretchedSpriteScale(640, 1024), 0.625, 1e-9)
end

return test
