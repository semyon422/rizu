---@class gui.composition.Strategies
local Strategies = {
	Stack = require("gui.composition.Stack"),
	Column = require("gui.composition.Column"),
	Flow = require("gui.composition.Flow"),
	Track = require("gui.composition.Track"),
	Anchor = require("gui.composition.Anchor")
}

return Strategies
