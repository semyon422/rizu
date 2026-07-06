---@class gui.composition.Strategies
local Strategies = {
	Stack = require("gui.composition.Stack"),
	Flex = require("gui.composition.Flex"),
	Flow = require("gui.composition.Flow"),
	Anchor = require("gui.composition.Anchor"),
}

return Strategies
