local class = require("class")

---@class rizu.editor.EditorRuntimeState
---@operator call: rizu.editor.EditorRuntimeState
---@field loaded boolean
---@field resourcesLoaded boolean
---@field visual chartedit.Visual?
---@field wave table?
---@field changes Changes?
local EditorRuntimeState = class()

function EditorRuntimeState:new()
	self.loaded = false
	self.resourcesLoaded = false
end

---@param loaded boolean
function EditorRuntimeState:setLoaded(loaded)
	self.loaded = loaded
end

---@return boolean
function EditorRuntimeState:isLoaded()
	return self.loaded
end

---@param loaded boolean
function EditorRuntimeState:setResourcesLoaded(loaded)
	self.resourcesLoaded = loaded
end

---@return boolean
function EditorRuntimeState:isResourcesLoaded()
	return self.resourcesLoaded
end

---@param visual chartedit.Visual?
function EditorRuntimeState:setVisual(visual)
	self.visual = visual
end

---@return chartedit.Visual?
function EditorRuntimeState:getVisual()
	return self.visual
end

---@param wave table?
function EditorRuntimeState:setWave(wave)
	self.wave = wave
end

---@return table?
function EditorRuntimeState:getWave()
	return self.wave
end

---@param changes Changes?
function EditorRuntimeState:setChanges(changes)
	self.changes = changes
end

---@return Changes?
function EditorRuntimeState:getChanges()
	return self.changes
end

return EditorRuntimeState
