local PlayfieldRenderer = require("rizu.gameplay.views.PlayfieldRenderer")
local Sprite = require("rizu.skin.easy_lua.Sprite")

---A minimal renderer fixture, deliberately not registered as a selectable skin.
---@class rizu.skin.test.ResourceRenderer : rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.skin.test.ResourceRenderer
---@field sprite rizu.skin.easy_lua.Sprite?
---@field runtime_loaded boolean
---@field draw_count integer
local ResourceRenderer = PlayfieldRenderer + {}

---@param game sphere.GameController
function ResourceRenderer:new(game)
	PlayfieldRenderer.new(self, game)
	self.runtime_loaded = false
	self.draw_count = 0
end

---@param context rizu.skin.SkinResourceContext
---@return rizu.skin.SkinResourceRequest.Asset[]
function ResourceRenderer:getResourceRequests(context)
	return {
		{name = "note", path = "icon_x.png"},
		{name = "alias", path = "./icon_x.png"},
	}
end

---Images have already been installed. No reading, decoding, or upload happens here.
function ResourceRenderer:load()
	assert(self:isResourcesReady() and self.resources, "test renderer resources are not ready")
	if self.runtime_loaded then return end
	self.sprite = Sprite({image = self.resources.assets.note, x = 16, y = 16})
	self.runtime_loaded = true
end

function ResourceRenderer:unload()
	self.sprite = nil
	self.runtime_loaded = false
end

---@param width number
---@param height number
---@param transform love.Transform
function ResourceRenderer:draw(width, height, transform)
	if not self:isResourcesReady() or not self.runtime_loaded or not self.sprite then return end
	love.graphics.push("all")
	love.graphics.applyTransform(transform)
	self.sprite:draw()
	love.graphics.pop()
	self.draw_count = self.draw_count + 1
end

---@param player rizu.preview.NotesPreviewPlayer?
---@param width number
---@param height number
function ResourceRenderer:drawPreview(player, width, height)
	if not self:isResourcesReady() or not self.runtime_loaded or not self.sprite then return end
	self.sprite:draw()
	self.draw_count = self.draw_count + 1
end

return ResourceRenderer
