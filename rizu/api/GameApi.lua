local class = require("class")
local Charts = require("rizu.api.Charts")
local Scores = require("rizu.api.Scores")
local Media = require("rizu.api.Media")
local Online = require("rizu.api.Online")
local Play = require("rizu.api.Play")
local Result = require("rizu.api.Result")
local Gameplay = require("rizu.api.Gameplay")
local Skins = require("rizu.api.Skins")
local Input = require("rizu.api.Input")
local Library = require("rizu.api.Library")
local App = require("rizu.api.App")
local VideoExport = require("rizu.api.VideoExport")

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
---@field skins rizu.api.Skins Gameplay skins: the list for a chart, and the chosen one.
---@field input rizu.api.Input Key bindings.
---@field library rizu.api.Library Chart folders and scanning them.
---@field app rizu.api.App The user interface, the audio device, screenshots.
---@field video_export rizu.api.VideoExport Frames the UI draws, written to an animated WebP with the system ffmpeg.
---@field settings rizu.config.Config Every setting. Keys are in `rizu.config.Settings.keys`, see `rizu/config/spec.md`.
---@field version integer Which API this is. A user interface built for another number may break.
---@field fake boolean? True when this is `rizu.api.fake.FakeGameApi` and there is no game behind it.
local GameApi = class()

---One integer, raised when something is removed or changes what it means. Adding is free.
GameApi.version = 1

---@param game sphere.GameController
function GameApi:new(game)
	self.charts = Charts(game.chartSelector, game.selectionCoordinator)
	self.scores = Scores(game.scoreSelector, game.resultController)
	self.media = Media(game.backgroundModel, game.previewModel)
	self.online = Online(game)
	self.play = Play(game)
	self.result = Result(game)
	self.gameplay = Gameplay(game)
	self.skins = Skins(game)
	self.input = Input(game)
	self.library = Library(game)
	self.app = App(game)
	self.video_export = VideoExport()
	self.settings = game.settings
end

---Forgets the listeners of every area. `UserInterfaceManager` calls this before it creates a new user interface.
function GameApi:removeListeners()
	for _, area in pairs(self) do
		if type(area) == "table" and area.removeListeners then
			area:removeListeners()
		end
	end
end

return GameApi
