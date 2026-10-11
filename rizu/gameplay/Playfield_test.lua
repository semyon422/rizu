local Playfield = require("rizu.gameplay.Playfield")
local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local Settings = require("rizu.config.Settings")
local FakeFilesystem = require("fs.FakeFilesystem")
---@param renderer rizu.gameplay.views.PlayfieldRenderer
local function maniaGame(renderer)
	local settings = Settings.createConfig(FakeFilesystem())
	local skin = {}
	return {
		rhythm_engine = {chartmeta = {mode = "mania"}, chart = {inputMode = "4key"}},
		settings = settings,
		skinRegistry = {
			getSkinForInputMode = function() return skin end,
			loadSkin = function() return renderer end,
		},
	}
end
local test = {}

---@param t testing.T
function test.asks_the_registry_for_a_skin_of_the_chart_gamemode(t)
	for _, case in ipairs({{"osu", "1osu", true}, {"catch", "1fruits", false}, {"taiko", "1taiko", false},
		{"sdvx", "4bt2fx2laserleft2laserright", false}, {"mania", "4key", false}}) do
		local renderer = PlayfieldRenderer({})
		local game = maniaGame(renderer)
		local requested ---@type string[]
		game.skinRegistry.getSkinForInputMode = function(_, gamemode, input_mode)
			requested = {gamemode, input_mode}
			return {}
		end
		game.rhythm_engine = {chartmeta = {mode = case[1]}, chart = {inputMode = case[2]}}
		local playfield = Playfield(game)
		playfield:load()
		t:eq(playfield.renderer, renderer)
		t:tdeq(requested, {case[1], case[2]})
		t:eq(playfield:usesPointer(), case[3])
		t:eq(playfield:isExperimental(), case[1] ~= "mania")
	end
end

---@param t testing.T
function test.keeps_skin_renderer_selection(t)
	local skin_renderer = PlayfieldRenderer({})
	local game = maniaGame(skin_renderer)
	local playfield = Playfield(game)
	playfield:load()
	t:eq(playfield.renderer, skin_renderer)
end

---@param t testing.T
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
	local game = maniaGame(renderer)
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
	local playfield = Playfield(maniaGame(renderer))
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
	local playfield = Playfield(maniaGame(renderer))
	t:eq(playfield.renderer, nil)
	t:eq(loads, 0)
	playfield:load()
	t:eq(playfield.renderer, renderer)
	t:eq(loads, 2)
end

---@param t testing.T
function test.skin_teardown_after_background_once(t)
	local renderer = PlayfieldRenderer({})
	local calls = {} ---@type string[]
	renderer.loadBackgroundHud = function() calls[#calls + 1] = "background-load" end
	renderer.load = function() calls[#calls + 1] = "runtime-load" end
	renderer.unloadBackgroundHud = function() calls[#calls + 1] = "background-unload" end
	renderer.unload = function() calls[#calls + 1] = "runtime-unload" end
	local playfield = Playfield(maniaGame(renderer))
	playfield:load()
	playfield:unload()
	playfield:unload()
	t:tdeq(calls, {"background-load", "runtime-load", "background-unload", "runtime-unload"})
end

---@param t testing.T
function test.runtime_load_failure_cleans_up_and_clears_renderer(t)
	local renderer = PlayfieldRenderer({})
	local released = 0
	renderer.load = function() error("runtime failure") end
	renderer.unload = function() released = released + 1 end
	local playfield = Playfield(maniaGame(renderer))
	t:assert(not pcall(playfield.load, playfield))
	t:eq(playfield.renderer, nil)
	t:eq(released, 1)
end

---@param t testing.T
function test.retry_reuses_renderer_and_dirty_config_after_engine_recreation(t)
	local renderer = PlayfieldRenderer({})
	local game = maniaGame(renderer)
	local creates, loads = 0, 0
	local config = {has_unsaved_changes = true, save = function() return false, "disk full" end}
	game.skinRegistry.loadSkin = function()
		creates = creates + 1
		return renderer, config, "config.json"
	end
	renderer.load = function() loads = loads + 1 end
	local playfield = Playfield(game)
	playfield:load()
	playfield:unload()
	game.rhythm_engine = {chartmeta = {mode = "mania"}, chart = {inputMode = "4key"}}
	playfield:load()
	t:eq(creates, 1)
	t:eq(loads, 2)
	t:eq(playfield.skin_config, config)
	t:eq(playfield:getPlayfield(), renderer)
	playfield:unload()
	playfield:clearSkin()
	t:eq(playfield.skin_config, config)
end

---@param t testing.T
function test.skin_replacement_saves_config_and_failed_save_preserves_it(t)
	local renderer = PlayfieldRenderer({})
	local game = maniaGame(renderer)
	local saves, creates = 0, 0
	local save_ok = false
	local config = {has_unsaved_changes = true, save = function()
		saves = saves + 1
		return save_ok, "disk full"
	end}
	game.skinRegistry.loadSkin = function()
		creates = creates + 1
		return renderer, config, "config.json"
	end
	local playfield = Playfield(game)
	playfield:load()
	playfield:unload()
	local replacement = {}
	game.skinRegistry.getSkinForInputMode = function() return replacement end
	t:eq(pcall(playfield.load, playfield), false)
	t:eq(playfield.skin_config, config)
	t:eq(creates, 1)
	save_ok = true
	playfield:load()
	t:eq(saves, 2)
	t:eq(creates, 2)
	playfield:unload()
end

---@param t testing.T
function test.canceled_skin_construction_cannot_publish_or_start_runtime(t)
	local renderer = PlayfieldRenderer({})
	local game = maniaGame(renderer)
	local loads, unloads = 0, 0
	renderer.load = function() loads = loads + 1 end
	renderer.unload = function() unloads = unloads + 1 end
	game.skinRegistry.loadSkin = function() coroutine.yield(); return renderer end
	local playfield = Playfield(game)
	local co = coroutine.create(function() playfield:load() end)
	assert(coroutine.resume(co))
	playfield:unload()
	playfield:clearSkin()
	assert(coroutine.resume(co))
	t:eq(playfield:getPlayfield(), nil)
	t:eq(playfield.skin_renderer, nil)
	t:eq(loads, 0)
	t:eq(unloads, 1)
end

return test
