local EditorRuntimeState = require("rizu.editor.state.EditorRuntimeState")

local test = {}

---@param t testing.T
function test.defaults_to_not_loaded(t)
	local state = EditorRuntimeState()

	t:eq(state:isLoaded(), false)
	t:eq(state:isResourcesLoaded(), false)
	t:eq(state:getVisual(), nil)
	t:eq(state:getWave(), nil)
	t:eq(state:getChanges(), nil)
end

---@param t testing.T
function test.stores_runtime_values(t)
	local state = EditorRuntimeState()
	local visual = {}
	local wave = {}
	local changes = {}

	state:setLoaded(true)
	state:setResourcesLoaded(true)
	state:setVisual(visual)
	state:setWave(wave)
	state:setChanges(changes)

	t:eq(state:isLoaded(), true)
	t:eq(state:isResourcesLoaded(), true)
	t:eq(state:getVisual(), visual)
	t:eq(state:getWave(), wave)
	t:eq(state:getChanges(), changes)
end

return test
