local Playfield = require("rizu.gameplay.Playfield")
local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local test = {}

---@param t testing.T
function test.selects_osu_mode_renderers_before_rules_are_created(t)
	local game = {
		rhythm_engine = {chartmeta = {mode = "osu"}},
		gameplayInteractor = {},
	}
	local playfield = Playfield(game)
	playfield:load()
	t:eq(playfield.renderer, playfield.osu_aim)
	t:eq(playfield:usesPointer(), true)
	t:eq(playfield:isExperimental(), true)
end

---@param t testing.T
function test.selects_sdvx_renderer_from_chart_mode(t)
	local game = {rhythm_engine = {chartmeta = {mode = "sdvx"}}}
	local playfield = Playfield(game)
	playfield:load()
	t:eq(playfield.renderer, playfield.sdvx)
	t:eq(playfield:isExperimental(), true)
end

---@param t testing.T
function test.selects_fruits_and_taiko_renderers_from_chart_mode(t)
	local game = {rhythm_engine = {chartmeta = {mode = "catch"}}}
	local playfield = Playfield(game)
	playfield:load()
	t:eq(playfield.renderer, playfield.osu_catch)

	game.rhythm_engine = {catch_rules = {}}
	playfield:unload()
	playfield:load()
	t:eq(playfield.renderer, playfield.catch)

	game.rhythm_engine = {chartmeta = {mode = "taiko"}}
	playfield:unload()
	playfield:load()
	t:eq(playfield.renderer, playfield.taiko)
end

---@param t testing.T
function test.keeps_mania_renderer_selection(t)
	local mania_renderer = PlayfieldRenderer({})
	local game = {
		rhythm_engine = {chartmeta = {mode = "mania"}},
		gameplayInteractor = {mania_renderer = mania_renderer},
	}
	local playfield = Playfield(game)
	playfield:load()
	t:eq(playfield.renderer, mania_renderer)
end

function test.dispatches_hud_to_active_renderer(t)
	local renderer = PlayfieldRenderer({})
	---@type number?
	local updated
	---@type table
	local drawn = {}
	renderer.updateHud = function(_, dt) updated = dt end
	renderer.drawHud = function(_, width, height, transform)
		drawn = {width, height, transform}
	end
	local game = {
		rhythm_engine = {chartmeta = {mode = "mania"}},
		gameplayInteractor = {mania_renderer = renderer},
	}
	local playfield = Playfield(game)
	playfield:load()
	playfield:updateHud(0.25)
	local transform = love.math.newTransform()
	playfield:drawHud(320, 240, transform)
	t:eq(updated, 0.25)
	t:eq(drawn[1], 320)
	t:eq(drawn[2], 240)
	t:eq(drawn[3], transform)
end

---@param t testing.T
function test.unloads_renderer_and_clears_selection(t)
	local renderer = PlayfieldRenderer({})
	---@type string[]
	local calls = {}
	renderer.unloadBackgroundHud = function()
		calls[#calls + 1] = "background"
	end
	renderer.unload = function()
		calls[#calls + 1] = "renderer"
	end
	local playfield = Playfield({
		rhythm_engine = {chartmeta = {mode = "mania"}},
		gameplayInteractor = {mania_renderer = renderer},
	})
	playfield:load()
	playfield:unload()
	t:eq(calls[1], "background")
	t:eq(calls[2], "renderer")
	t:eq(playfield.renderer, nil)
	playfield:unload()
	t:eq(#calls, 2)
end

---@param t testing.T
function test.constructor_does_not_load_renderer(t)
	local renderer = PlayfieldRenderer({})
	local loads = 0
	renderer.load = function() loads = loads + 1 end
	renderer.loadBackgroundHud = function() loads = loads + 1 end
	local playfield = Playfield({
		rhythm_engine = {chartmeta = {mode = "mania"}},
		gameplayInteractor = {mania_renderer = renderer},
	})
	t:eq(playfield.renderer, nil)
	t:eq(loads, 0)
	playfield:load()
	t:eq(playfield.renderer, renderer)
	t:eq(loads, 2)
end

---@param t testing.T
function test.prepared_resources_teardown_after_runtime_and_background_once(t)
	local renderer = PlayfieldRenderer({})
	local calls = {} ---@type string[]
	renderer.loadBackgroundHud = function() calls[#calls + 1] = "background-load" end
	renderer.load = function() calls[#calls + 1] = "runtime-load" end
	renderer.unloadBackgroundHud = function() calls[#calls + 1] = "background-unload" end
	renderer.unload = function() calls[#calls + 1] = "runtime-unload" end
	renderer.unloadResources = function() calls[#calls + 1] = "resources-unload" end
	local playfield = Playfield({rhythm_engine = {chartmeta = {mode = "mania"}},
		gameplayInteractor = {mania_renderer = renderer}})
	playfield:load()
	playfield:unload()
	playfield:unload()
	t:tdeq(calls, {"background-load", "runtime-load", "background-unload", "runtime-unload", "resources-unload"})
end

---@param t testing.T
function test.runtime_load_failure_cleans_up_and_clears_renderer(t)
	local renderer = PlayfieldRenderer({})
	local released = 0
	renderer.load = function() error("runtime failure") end
	renderer.unloadResources = function() released = released + 1 end
	local playfield = Playfield({rhythm_engine = {chartmeta = {mode = "mania"}},
		gameplayInteractor = {mania_renderer = renderer}})
	t:assert(not pcall(playfield.load, playfield))
	t:eq(playfield.renderer, nil)
	t:eq(released, 1)
end

return test
