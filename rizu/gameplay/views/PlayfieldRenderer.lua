local class = require("class")

---@class rizu.gameplay.views.PlayfieldRenderer
---@operator call: rizu.gameplay.views.PlayfieldRenderer
local PlayfieldRenderer = class()

---@param game sphere.GameController
function PlayfieldRenderer:new(game)
	self.game = game
end

function PlayfieldRenderer:load() end

function PlayfieldRenderer:unload() end

---@param x number Window x coordinate in drawable pixels
---@param y number Window y coordinate in drawable pixels
---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
---@return number
---@return number
function PlayfieldRenderer:toChart(x, y, width, height, transform)
	return x, y
end

---@param width number Gameplay viewport width in drawable pixels
---@param height number Gameplay viewport height in drawable pixels
---@param transform love.Transform Maps viewport coordinates to drawable pixels
function PlayfieldRenderer:draw(width, height, transform) end

---@param player rizu.preview.NotesPreviewPlayer
---@param width number Preview width in drawable pixels
---@param height number Preview height in drawable pixels
function PlayfieldRenderer:drawPreview(player, width, height) end

return PlayfieldRenderer
