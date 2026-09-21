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

return PlayfieldRenderer
