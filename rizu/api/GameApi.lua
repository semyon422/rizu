local class = require("class")
local Charts = require("rizu.api.Charts")

---Everything a user interface needs from the game, one documented object per area.
---A UI gets it as `ui.api`. What is not here yet is still reachable through `ui.game`.
---@class rizu.api.GameApi
---@operator call: rizu.api.GameApi
---@field charts rizu.api.Charts
local GameApi = class()

---@param game sphere.GameController
function GameApi:new(game)
	self.charts = Charts(game.chartSelector)
end

return GameApi
