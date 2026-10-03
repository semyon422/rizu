local class = require("class")

---@alias rizu.skin.PlayfieldPreparation.State "loading"|"ready"|"failed"|"released"

---Owns renderer lifecycle, without prescribing how a skin loads its resources.
---@class rizu.skin.PlayfieldPreparation
---@operator call: rizu.skin.PlayfieldPreparation
---@field renderer rizu.gameplay.views.PlayfieldRenderer
---@field state rizu.skin.PlayfieldPreparation.State
---@field error string?
---@field released boolean
---@field background_loaded boolean
---@field runtime_started boolean
local PlayfieldPreparation = class()

---@param renderer rizu.gameplay.views.PlayfieldRenderer
function PlayfieldPreparation:new(renderer)
	self.renderer = renderer
	self.state = "loading"
	self.released = false
	self.background_loaded = false
	self.runtime_started = false
end

---Publish the renderer only after its own load hook succeeds.
---@param background boolean? Gameplay loads its background HUD; preview does not.
---@return boolean
function PlayfieldPreparation:load(background)
	if self.state == "ready" then return true end
	if self.released or self.runtime_started then return false end
	local ok, err = xpcall(function()
		if background then
			self.background_loaded = true
			self.renderer:loadBackgroundHud()
		end
		if self.released then return end
		self.runtime_started = true
		self.renderer:load()
	end, debug.traceback)
	if self.released then
		-- A skin's load hook may yield and finish constructing after teardown.
		if background then pcall(self.renderer.unloadBackgroundHud, self.renderer) end
		pcall(self.renderer.unload, self.renderer)
		return false
	end
	if not ok then
		self:release()
		self.error = tostring(err)
		self.state = "failed"
		return false
	end
	self.state = "ready"
	return true
end

---Idempotent; attempt runtime cleanup even if background teardown throws.
function PlayfieldPreparation:release()
	if self.released then return end
	self.released = true
	self.state = "released"
	local renderer = self.renderer
	local function cleanup(f)
		local ok, err = pcall(f, renderer)
		if not ok then self.error = self.error or tostring(err) end
	end
	if self.background_loaded then cleanup(renderer.unloadBackgroundHud) end
	if self.runtime_started then cleanup(renderer.unload) end
	self.background_loaded = false
	self.runtime_started = false
end

---@return rizu.gameplay.views.PlayfieldRenderer?
function PlayfieldPreparation:getPlayfield()
	if self.state == "ready" and not self.released then return self.renderer end
end

return PlayfieldPreparation
