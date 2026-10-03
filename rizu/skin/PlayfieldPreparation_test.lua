local Preparation = require("rizu.skin.PlayfieldPreparation")
local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local test = {}

---@param t testing.T
function test.readiness_and_gameplay_cleanup_order(t)
	local renderer = PlayfieldRenderer({})
	local calls = {} ---@type string[]
	renderer.loadBackgroundHud = function() calls[#calls + 1] = "background" end
	renderer.load = function() calls[#calls + 1] = "load" end
	renderer.unloadBackgroundHud = function() calls[#calls + 1] = "unload-background" end
	renderer.unload = function() calls[#calls + 1] = "unload" end
	local p = Preparation(renderer)
	t:eq(p:getPlayfield(), nil)
	t:assert(p:load(true))
	t:assert(p:load(true))
	t:eq(p:getPlayfield(), renderer)
	p:release()
	p:release()
	t:tdeq(calls, {"background", "load", "unload-background", "unload"})
end

---@param t testing.T
function test.skin_load_failure_cleans_up_without_background_in_preview(t)
	local renderer = PlayfieldRenderer({})
	local unloaded = 0
	renderer.load = function() error("skin resource failure") end
	renderer.unload = function() unloaded = unloaded + 1 end
	renderer.loadBackgroundHud = function() error("preview must not load background") end
	local p = Preparation(renderer)
	t:eq(p:load(false), false)
	t:eq(p.state, "failed")
	t:eq(p:getPlayfield(), nil)
	t:eq(unloaded, 1)
	p:release()
	t:eq(unloaded, 1)
end

---@param t testing.T
function test.background_failure_still_cleans_up(t)
	local renderer = PlayfieldRenderer({})
	local unloaded = 0
	renderer.loadBackgroundHud = function() error("background load failed") end
	renderer.unloadBackgroundHud = function() unloaded = unloaded + 1 end
	local p = Preparation(renderer)
	t:eq(p:load(true), false)
	t:eq(unloaded, 1)
	t:eq(p:getPlayfield(), nil)
end

---@param t testing.T
function test.throwing_background_teardown_does_not_skip_skin_cleanup(t)
	local renderer = PlayfieldRenderer({})
	local unloaded = 0
	renderer.unloadBackgroundHud = function() error("bad teardown") end
	renderer.unload = function() unloaded = unloaded + 1 end
	local p = Preparation(renderer)
	p:load(true)
	p:release()
	p:release()
	t:eq(unloaded, 1)
	t:assert(p.error:find("bad teardown", 1, true))
end

---@param t testing.T
function test.skin_load_yield_cannot_publish_after_release(t)
	local renderer = PlayfieldRenderer({})
	local object ---@type table?
	renderer.load = function() coroutine.yield(); object = {} end
	renderer.unload = function() object = nil end
	local p = Preparation(renderer)
	local ready ---@type boolean?
	local co = coroutine.create(function() ready = p:load(false) end)
	assert(coroutine.resume(co))
	p:release()
	assert(coroutine.resume(co))
	t:eq(ready, false)
	t:eq(object, nil)
	t:eq(p:getPlayfield(), nil)
end

return test
