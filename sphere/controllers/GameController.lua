local class = require("class")

local OnlineModel = require("sphere.models.OnlineModel")
local ModifierSelectModel = require("sphere.models.ModifierSelectModel")
local NoteSkinModel = require("sphere.models.NoteSkinModel")
local InputModel = require("sphere.models.InputModel")
local ChartSelector = require("rizu.select.ChartSelector")
local ScoreSelector = require("rizu.select.ScoreSelector")
local CollectionSelector = require("rizu.select.CollectionSelector")
local MultiplayerModel = require("sphere.models.MultiplayerModel")
local EditorModel = require("rizu.editor.EditorModel")
local SpeedModel = require("sphere.models.SpeedModel")
local TimeRateModel = require("sphere.models.TimeRateModel")
local ResourceModel = require("sphere.models.ResourceModel")
local PauseModel = require("sphere.models.PauseModel")
local JoystickModel = require("sphere.models.JoystickModel")
local OffsetModel = require("sphere.models.OffsetModel")

local SelectionCoordinator = require("rizu.select.SelectionCoordinator")
local ModifierCoordinator = require("rizu.select.ModifierCoordinator")
local LibraryDropManager = require("rizu.library.LibraryDropManager")
local ChartExporter = require("rizu.library.ChartExporter")
local SelectionActions = require("rizu.select.SelectionActions")
local ResultController = require("sphere.controllers.ResultController")
local MultiplayerController = require("sphere.controllers.MultiplayerController")
local EditorController = require("rizu.editor.EditorController")

local OffsetController = require("sphere.controllers.gameplay.OffsetController")

local NotificationModel = require("sphere.ui.NotificationModel")
local BackgroundModel = require("sphere.ui.BackgroundModel")
local PreviewModel = require("rizu.preview.PreviewModel")

local Persistence = require("sphere.persistence.Persistence")
local App = require("sphere.app.App")
local UserInterfaceModel = require("sphere.models.UserInterfaceModel")

local PackageManager = require("sphere.pkg.PackageManager")
local SeaClient = require("sphere.online.SeaClient")
local OnlineClient = require("sphere.online.OnlineClient")
local OnlineWrapper = require("sphere.online.OnlineWrapper")
local DifftablesSync = require("sea.difftables.DifftablesSync")
local ClientRemote = require("sea.app.remotes.ClientRemote")
local ClientRemoteValidation = require("sea.app.remotes.ClientRemoteValidation")

local ComputeContext = require("sea.compute.ComputeContext")
local ReplayBase = require("sea.replays.ReplayBase")

local LoveFilesystem = require("fs.LoveFilesystem")
local LoveTimer = require("time.LoveTimer")

local GameplayInteractor = require("rizu.gameplay.GameplayInteractor")
local GameInteractor = require("rizu.game.GameInteractor")

local ResourceLoader = require("rizu.files.ResourceLoader")
local ResourceFinder = require("rizu.files.ResourceFinder")

local RhythmEngine = require("rizu.engine.RhythmEngine")

local GlobalTimer = require("rizu.game.GlobalTimer")

local MultiplayerClient = require("sea.multi.MultiplayerClient")

local DlcManager = require("rizu.dlc.DlcManager")

---@class sphere.GameController
---@operator call: sphere.GameController
local GameController = class()

function GameController:new()
	self.fs = LoveFilesystem()

	self.rhythm_engine = RhythmEngine(self.fs)

	self.packageManager = PackageManager()

	self.persistence = Persistence()
	self.settings_config = assert(self.persistence.configManager:get("settings"))
	self.app = App(self.persistence)
	self.uiModel = UserInterfaceModel(self)

	self.library = self.persistence.library
	self.dlcManager = DlcManager(self.library, self.persistence.configModel)

	self.online_client = OnlineClient()
	self.multiplayer_client = MultiplayerClient()
	self.client_remote = ClientRemoteValidation(ClientRemote(self.online_client, self.persistence.library, self.multiplayer_client))
	self.seaClient = SeaClient(self.online_client, self.client_remote)
	self.difftables_sync = DifftablesSync(self.seaClient.remote.difftables, self.persistence.library.difftablesRepo)
	self.online_wrapper = OnlineWrapper(self.online_client, self.seaClient.remote)

	self.onlineModel = OnlineModel(self.persistence.configModel, self.seaClient)

	self.multiplayer_client.server_remote = self.seaClient.remote

	self.noteSkinModel = NoteSkinModel(self.persistence.configModel, self.packageManager)
	self.inputModel = InputModel(self.persistence.configModel)
	self.resourceModel = ResourceModel(
		self.persistence.configModel,
		self.persistence.fileFinder
	)
	self.pauseModel = PauseModel(self.persistence.configModel, self.rhythm_engine)
	self.editorModel = EditorModel(
		self.persistence.configModel,
		self.resourceModel
	)
	self.speedModel = SpeedModel(self.persistence.configModel)
	self.computeContext = ComputeContext()
	self.replayBase = ReplayBase()

	self.multiplayer_client.replay_base = self.replayBase

	self.timeRateModel = TimeRateModel(self.replayBase)
	self.modifierSelectModel = ModifierSelectModel(self.replayBase)
	self.collectionSelector = CollectionSelector(
		self.persistence.configModel,
		self.persistence.library
	)
	self.chartSelector = ChartSelector(
		self.persistence.configModel,
		self.persistence.library,
		self.fs,
		self.collectionSelector,
		LoveTimer()
	)
	self.scoreSelector = ScoreSelector(
		self.persistence.configModel,
		self.persistence.library,
		self.onlineModel,
		self.replayBase,
		self.chartSelector.state
	)

	self.multiplayer_client.chart_selector = self.chartSelector

	self.multiplayerModel = MultiplayerModel(
		self.persistence.library,
		self.rhythm_engine,
		self.persistence.configModel,
		self.chartSelector,
		self.onlineModel,
		self.dlcManager,
		self.replayBase,
		self.multiplayer_client
	)
	self.offsetModel = OffsetModel(
		self.persistence.configModel,
		self.persistence.library.chartsRepo
	)

	self.joystickModel = JoystickModel(self.persistence.configModel)

	self.library = self.persistence.library
	self.configModel = self.persistence.configModel
	self.fileFinder = self.persistence.fileFinder
	self.difficultyModel = self.persistence.difficultyModel

	self.discordModel = self.app.discordModel
	self.windowModel = self.app.windowModel

	self.backgroundModel = BackgroundModel()
	self.notificationModel = NotificationModel()
	self.previewModel = PreviewModel(
		self.persistence.configModel,
		self.replayBase,
		self
	)

	self.selectionCoordinator = SelectionCoordinator(
		self.chartSelector,
		self.scoreSelector,
		self.collectionSelector,
		self.backgroundModel,
		self.previewModel,
		self.windowModel
	)
	self.modifierCoordinator = ModifierCoordinator(
		self.chartSelector,
		self.scoreSelector,
		self.modifierSelectModel,
		self.configModel,
		self.multiplayerModel,
		self.replayBase,
		self.previewModel
	)
	self.libraryDropManager = LibraryDropManager(self.library)
	self.chartExporter = ChartExporter(self.library)
	self.selectionActions = SelectionActions(
		self.chartSelector,
		self.library,
		self.onlineModel
	)

	self.resultController = ResultController(self)
	self.multiplayerController = MultiplayerController(
		self.multiplayerModel,
		self.configModel,
		self.chartSelector,
		self.replayBase
	)
	self.offsetController = OffsetController(
		self.library,
		self.computeContext,
		self.offsetModel,
		self.rhythm_engine,
		self.notificationModel
	)

	self.resource_finder = ResourceFinder(self.fs)
	self.resource_loader = ResourceLoader(self.fs, self.resource_finder)

	self.editorController = EditorController(
		self.chartSelector,
		self.editorModel,
		self.noteSkinModel,
		self.configModel,
		self.resourceModel,
		self.windowModel,
		self.library,
		self.fileFinder,
		self.previewModel,
		self.replayBase,
		self.resource_finder,
		self.resource_loader
	)

	self.gameplayInteractor = GameplayInteractor(self)
	self.gameInteractor = GameInteractor(self)

	self.global_timer = GlobalTimer()
end

function GameController:load()
	self.packageManager:load()

	self.persistence:load()
	self.app:load()

	self.uiModel:load()

	local configModel = self.configModel

	self.replayBase:importReplayBase(configModel.configs.play)
	self.modifierSelectModel:updateAdded()

	self.seaClient:load(self.persistence.configModel.configs.urls.websocket, function()
		self.onlineModel.authManager:checkSession()
		self.online_wrapper:updateLeaderboards()
		if not love.filesystem.read("disable_difftables_sync.txt") then
			print("sync difftables", self.difftables_sync:sync())
		end
	end)

	self.noteSkinModel:load()
	self.dlcManager:load()
	self.collectionSelector:load()
	self.selectionCoordinator:load()
	self.modifierCoordinator:load()

	self.multiplayerController:load()

	self.multiplayerModel:connect()

	self.backgroundModel:load()
end

function GameController:unload()
	self.selectionCoordinator:unload()
	self.modifierCoordinator:unload()
	self.previewModel:release()
	self.multiplayerController:unload()
	self.ui:unload()
	self.app:unload()
	self.persistence:unload()
end

---@param dt number
function GameController:update(dt)
	self.app:update()

	self.selectionCoordinator:update(function(...) self.modifierCoordinator:applyModifierMeta(...) end)
	self.modifierCoordinator:update()

	self.joystickModel:update(dt)

	self.multiplayerController:update()
	self.gameplayInteractor:update()
	self.dlcManager:update()

	self.library:update()

	self.backgroundModel:update()
	self.previewModel:update()
	self.ui:update(dt)
	self.notificationModel:update()

	self.seaClient:update()
end

function GameController:recreateRhythmEngine()
	if self.rhythm_engine then
		self.rhythm_engine:unload()
	end
	self.rhythm_engine = RhythmEngine(self.fs)
	self.pauseModel:setRhythmEngine(self.rhythm_engine)
end

---@param ui sphere.IUserInterface
function GameController:setUI(ui)
	if self.ui then
		self.ui:unload()
		self.previewModel:stop()
	end

	self.ui = ui
	self.ui:load()
end

function GameController:draw()
	self.ui:draw()
end

---@param event table
function GameController:receive(event)
	if event.name == "update" then
		self:update(event[1])
		return
	elseif event.name == "draw" then
		self:draw()
		return
	elseif event.name == "quit" then
		self:unload()
		return
	end

	if event.name == "framestarted" then
		self.global_timer:setTime(event.time)
	end

	self.libraryDropManager:receive(event)

	self.ui:receive(event)
	self.app:receive(event)
	self.joystickModel:receive(event)
end

return GameController
