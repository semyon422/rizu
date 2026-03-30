local class = require("class")

---@class yi.Context
---@operator call: yi.Context
local Context = class()

---@param game sphere.GameController
---@param inputs ui.Inputs
---@param resources yi.Resources
function Context:new(game, inputs, resources)
	self.game = assert(game)
	self.inputs = assert(inputs)
	self.resources = resources
end

---@param background yi.Background
function Context:setLayers(background)
	self.background = background
end

return Context
