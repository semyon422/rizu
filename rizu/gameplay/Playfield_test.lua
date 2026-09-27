local Playfield = require("rizu.gameplay.Playfield")
local test = {}

---@param t testing.T
function test.selects_osu_mode_renderers_before_rules_are_created(t)
	local game = {
		rhythm_engine = {chartmeta = {mode = "osu"}},
		gameplayInteractor = {},
	}
	local playfield = Playfield(game)
	t:eq(playfield.renderer, playfield.osu_aim)
	t:eq(playfield:usesPointer(), true)
	t:eq(playfield:isExperimental(), true)
end

---@param t testing.T
function test.selects_sdvx_renderer_from_chart_mode(t)
	local game = {rhythm_engine = {chartmeta = {mode = "sdvx"}}}
	local playfield = Playfield(game)
	t:eq(playfield.renderer, playfield.sdvx)
	t:eq(playfield:isExperimental(), true)
end

---@param t testing.T
function test.selects_fruits_and_taiko_renderers_from_chart_mode(t)
	local game = {rhythm_engine = {chartmeta = {mode = "catch"}}}
	local playfield = Playfield(game)
	t:eq(playfield.renderer, playfield.osu_catch)

	game.rhythm_engine = {catch_rules = {}}
	playfield:refresh()
	t:eq(playfield.renderer, playfield.catch)

	game.rhythm_engine = {chartmeta = {mode = "taiko"}}
	playfield:refresh()
	t:eq(playfield.renderer, playfield.taiko)
end

---@param t testing.T
function test.keeps_mania_renderer_selection(t)
	local mania_renderer = {load = function() end, unload = function() end}
	local game = {
		rhythm_engine = {chartmeta = {mode = "mania"}},
		gameplayInteractor = {mania_renderer = mania_renderer},
	}
	local playfield = Playfield(game)
	t:eq(playfield.renderer, mania_renderer)
end

function test.dispatches_hud_to_active_renderer(t)
	local renderer = {
		load = function() end,
		unload = function() end,
		updateHud = function(self, dt) self.updated = dt end,
		drawHud = function(self, width, height, transform)
			self.drawn = {width, height, transform}
		end,
	}
	local game = {
		rhythm_engine = {chartmeta = {mode = "mania"}},
		gameplayInteractor = {mania_renderer = renderer},
	}
	local playfield = Playfield(game)
	playfield:updateHud(0.25)
	local transform = love.math.newTransform()
	playfield:drawHud(320, 240, transform)
	t:eq(renderer.updated, 0.25)
	t:eq(renderer.drawn[1], 320)
	t:eq(renderer.drawn[2], 240)
	t:eq(renderer.drawn[3], transform)
end

return test
