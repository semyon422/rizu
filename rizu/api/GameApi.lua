local class = require("class")
local Charts = require("rizu.api.Charts")
local Scores = require("rizu.api.Scores")
local Media = require("rizu.api.Media")
local Online = require("rizu.api.Online")
local Play = require("rizu.api.Play")
local Result = require("rizu.api.Result")
local Gameplay = require("rizu.api.Gameplay")

---Everything a user interface needs from the game, one documented object per area.
---A UI gets it as `ui.api`. What is not here yet is still reachable through `ui.game`.
---@class rizu.api.GameApi
---@operator call: rizu.api.GameApi
---@field charts rizu.api.Charts The chart library: lists, selection, search, filters, collections.
---@field scores rizu.api.Scores Scores of the selected chart.
---@field media rizu.api.Media Background and previews of the selected chart.
---@field online rizu.api.Online The player's account and the server connection.
---@field play rizu.api.Play Music speed, mods, judging, starting a play.
---@field result rizu.api.Result How the last play went, or a score loaded from the leaderboard.
---@field gameplay rizu.api.Gameplay The play in progress. Lua skins get this object too.
---@field settings rizu.config.Config Every setting. Keys are in `rizu.config.Settings.keys`, see `rizu/config/spec.md`.
---@field fake boolean? True when this is `rizu.api.fake.FakeGameApi` and there is no game behind it.
local GameApi = class()

---@param game sphere.GameController
function GameApi:new(game)
	self.charts = Charts(game.chartSelector, game.selectionCoordinator)
	self.scores = Scores(game.scoreSelector, game.resultController)
	self.media = Media(game.backgroundModel, game.previewModel)
	self.online = Online(game.online_client, game.avatar_cache)
	self.play = Play(game)
	self.result = Result(game)
	self.gameplay = Gameplay(game)
	self.settings = game.settings
end

return GameApi
