local class = require("class")
local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")
local FakeCharts = require("rizu.api.fake.FakeCharts")
local FakeScores = require("rizu.api.fake.FakeScores")
local FakeMedia = require("rizu.api.fake.FakeMedia")
local FakeOnline = require("rizu.api.fake.FakeOnline")
local FakePlay = require("rizu.api.fake.FakePlay")
local FakeResult = require("rizu.api.fake.FakeResult")
local FakeGameplay = require("rizu.api.fake.FakeGameplay")
local FakeSkins = require("rizu.api.fake.FakeSkins")
local FakeInput = require("rizu.api.fake.FakeInput")
local FakeLibrary = require("rizu.api.fake.FakeLibrary")
local FakeApp = require("rizu.api.fake.FakeApp")
local GameApi = require("rizu.api.GameApi")

---`rizu.api.GameApi` with no game behind it: a made-up library, scores and player, and settings
---that are never saved. Enough to run and test a user interface on its own.
---@class rizu.api.fake.FakeGameApi
---@operator call: rizu.api.fake.FakeGameApi
local FakeGameApi = class()

function FakeGameApi:new()
	self.fake = true
	self.version = GameApi.version
	self.settings = Settings.createConfig(FakeFilesystem())
	self.charts = FakeCharts()
	self.scores = FakeScores()
	self.media = FakeMedia()
	self.online = FakeOnline()
	self.play = FakePlay()
	self.result = FakeResult()
	self.gameplay = FakeGameplay()
	self.skins = FakeSkins()
	self.input = FakeInput()
	self.library = FakeLibrary()
	self.app = FakeApp()

	local function selected(chart)
		self.scores:setChart(chart)
		self.media:setChart(chart)
	end
	self.charts:on("selection_changed", selected)
	selected(self.charts:getSelectedChart())
end

---@param dt number
function FakeGameApi:update(dt)
	self.media:update(dt)
end

return FakeGameApi
