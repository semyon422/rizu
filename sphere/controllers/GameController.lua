local class = require("class")
local brand = require("brand")
local json = require("web.json")
local utf8validate = require("utf8validate")

local OnlineModel = require("rizu.online.OnlineModel")
local ModifierSelectModel = require("sphere.models.ModifierSelectModel")
local NoteSkinModel = require("sphere.models.NoteSkinModel")
local InputModel = require("sphere.models.InputModel")
local ChartSelector = require("rizu.select.ChartSelector")
local ScoreSelector = require("rizu.select.ScoreSelector")
local CollectionSelector = require("rizu.select.CollectionSelector")
local MultiplayerModel = require("rizu.online.MultiplayerModel")
local EditorInput = require("rizu.editor.EditorInput")
local EditorModel = require("rizu.editor.EditorModel")
local SpeedModel = require("sphere.models.SpeedModel")
local TimeRateModel = require("sphere.models.TimeRateModel")
local PauseModel = require("sphere.models.PauseModel")
local JoystickModel = require("sphere.models.JoystickModel")
local OffsetModel = require("sphere.models.OffsetModel")

local SelectionCoordinator = require("rizu.select.SelectionCoordinator")
local ModifierCoordinator = require("rizu.select.ModifierCoordinator")
local LibraryDropManager = require("rizu.library.LibraryDropManager")
local ChartExporter = require("rizu.library.ChartExporter")
local SelectionActions = require("rizu.select.SelectionActions")
local LocationDirectoryOpener = require("rizu.select.services.LocationDirectoryOpener")
local ModifierConfigPersistence = require("rizu.select.services.ModifierConfigPersistence")
local SelectionWindowSync = require("rizu.select.services.SelectionWindowSync")
local ResultController = require("sphere.controllers.ResultController")
local MultiplayerController = require("sphere.controllers.MultiplayerController")
local EditorController = require("rizu.editor.EditorController")

local OffsetController = require("sphere.controllers.gameplay.OffsetController")

local BackgroundModel = require("sphere.ui.BackgroundModel")
local PreviewModel = require("rizu.preview.PreviewModel")

local Persistence = require("sphere.persistence.Persistence")
local App = require("rizu.app.App")
local UserInterfaceManager = require("rizu.app.UserInterfaceManager")

local PackageManager = require("rizu.pkg.PackageManager")
local SeaClient = require("rizu.online.SeaClient")
local OnlineClient = require("rizu.online.OnlineClient")
local OnlineWrapper = require("rizu.online.OnlineWrapper")
local NetworkService = require("rizu.net.NetworkService")
local McpServer = require("mcp.Server")
local OpenAiAgent = require("ai.openai.Agent")
local AiChatModel = require("rizu.ai.ChatModel")
local AiProviderManager = require("rizu.ai.ProviderManager")
local GetToolFailuresTool = require("rizu.ai.GetToolFailuresTool")
local InspectRuntimeTool = require("rizu.ai.InspectRuntimeTool")
local LuaEvalTool = require("rizu.ai.LuaEvalTool")
local ReadFileTool = require("rizu.ai.ReadFileTool")
local SearchSourceTool = require("rizu.ai.SearchSourceTool")
local SourceLocationTool = require("rizu.ai.SourceLocationTool")
local ToolFailureLog = require("rizu.ai.ToolFailureLog")
local McpSessionStore = require("rizu.ai.McpSessionStore")
local RestartTool = require("rizu.ai.RestartTool")
local RuntimeStateTool = require("rizu.ai.RuntimeStateTool")
local ScreenshotTool = require("rizu.ai.ScreenshotTool")
local AiSystemPrompt = require("rizu.ai.SystemPrompt")
local NeedleModel = require("rizu.ai.NeedleModel")
local NeedleGpuProbe = require("rizu.ai.NeedleGpuProbe")
local NeedleGpuEncoderProbe = require("rizu.ai.NeedleGpuEncoderProbe")
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

---@param surface "agent"|"mcp"
---@param name string?
---@param arguments any
---@param err string
---@param failure_log rizu.ai.ToolFailureLog
local function logToolFailure(failure_log, surface, name, arguments, err)
	failure_log:add(surface, name, arguments, err)
	local ok, encoded = pcall(json.encode, {
		surface = surface,
		tool = name,
		arguments = arguments,
		error = err,
	})
	print("AI tool failure: " .. utf8validate(ok and encoded or tostring(err)))
end

---@class sphere.GameController
---@operator call: sphere.GameController
local GameController = class()

function GameController:new()
	self.fs = LoveFilesystem()

	self.rhythm_engine = RhythmEngine(self.fs)
	self.network = NetworkService()

	self.packageManager = PackageManager(self.network)

	self.persistence = Persistence()
	self.settings = self.persistence.settings
	self.app = App(self.persistence)
	self.user_interface_manager = UserInterfaceManager(self)

	self.library = self.persistence.library
	self.dlcManager = DlcManager(self.library, self.network)

	self.online_client = OnlineClient()
	self.multiplayer_client = MultiplayerClient()
	self.client_remote = ClientRemoteValidation(ClientRemote(self.online_client, self.persistence.library, self.multiplayer_client))
	self.seaClient = SeaClient(self.online_client, self.client_remote, self.network)
	self.difftables_sync = DifftablesSync(self.seaClient.remote.difftables, self.persistence.library.difftablesRepo)
	self.online_wrapper = OnlineWrapper(self.online_client, self.seaClient.remote)

	self.onlineModel = OnlineModel(self.persistence.configModel, self.seaClient)

	self.multiplayer_client.server_remote = self.seaClient.remote

	self.noteSkinModel = NoteSkinModel(self.persistence.configModel, self.packageManager)
	self.inputModel = InputModel(self.persistence.configModel)
	self.pauseModel = PauseModel(self.persistence.configModel, self.rhythm_engine)
	self.editorInput = EditorInput()
	self.editorModel = EditorModel({
		configModel = self.persistence.configModel,
		fs = self.fs,
		input = self.editorInput,
	})
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

	self.backgroundModel = BackgroundModel(self.network)
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
		SelectionWindowSync(self.windowModel)
	)
	self.modifierCoordinator = ModifierCoordinator(
		self.chartSelector,
		self.scoreSelector,
		self.modifierSelectModel,
		ModifierConfigPersistence(self.configModel),
		self.multiplayerModel,
		self.replayBase,
		self.previewModel
	)
	self.libraryDropManager = LibraryDropManager(self.library)
	self.chartExporter = ChartExporter(self.library)
	self.selectionActions = SelectionActions(
		self.chartSelector,
		self.library,
		self.onlineModel,
		LocationDirectoryOpener()
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
		self.rhythm_engine
	)

	self.resource_finder = ResourceFinder(self.fs)
	self.resource_loader = ResourceLoader(self.fs, self.resource_finder)

	self.editorController = EditorController({
		chartSelector = self.chartSelector,
		editorModel = self.editorModel,
		noteSkinModel = self.noteSkinModel,
		configModel = self.configModel,
		windowModel = self.windowModel,
		library = self.library,
		fileFinder = self.fileFinder,
		previewModel = self.previewModel,
		replayBase = self.replayBase,
		resource_finder = self.resource_finder,
		resource_loader = self.resource_loader,
		fs = self.fs,
		isModifierApplyRequested = function()
			return self.editorInput:isModifierApplyRequested()
		end,
	})

	self.gameplayInteractor = GameplayInteractor(self)
	self.gameInteractor = GameInteractor(self)

	self.global_timer = GlobalTimer()
end

function GameController:load()
	self.packageManager:load()

	self.persistence:load()
	self.network:setProxy(self.persistence.configModel.configs.network.socks5)

	local ai_config = self.persistence.configModel.configs.ai
	self.aiToolFailureLog = ToolFailureLog()
	self.aiProviderManager = AiProviderManager({
		config = ai_config,
		credentials = self.persistence.configModel.configs.ai_auth,
		scheduler = self.network.scheduler,
		request = function(url, body, options)
			return self.network:request(url, body, options)
		end,
		open_stream = function(url, options)
			return self.network:openStream(url, options)
		end,
		open_url = function(url) return love.system.openURL(url) end,
		save_config = function() self.persistence.configModel:write("ai") end,
		save_credentials = function() self.persistence.configModel:write("ai_auth") end,
	})
	local ai_tools = {
		SearchSourceTool(self.fs),
		InspectRuntimeTool(self),
		GetToolFailuresTool(self.aiToolFailureLog),
		SourceLocationTool(self),
		ReadFileTool(self.fs),
		LuaEvalTool(self),
	}
	local ai_agent = OpenAiAgent(self.aiProviderManager:getClient(), ai_tools, {
		streaming = true,
		max_tool_rounds = 50,
		on_tool_failure = function(name, arguments, err)
			logToolFailure(self.aiToolFailureLog, "agent", name, arguments, err)
		end,
	})
	self.aiChatModel = AiChatModel(ai_agent, AiSystemPrompt, {provider_manager = self.aiProviderManager})
	self.needleModel = NeedleModel(self.persistence.configModel.configs.needle)
	self.needleGpuProbe = NeedleGpuProbe()
	self.needleGpuEncoderProbe = NeedleGpuEncoderProbe()
	local mcp_config = self.persistence.configModel.configs.mcp
	if mcp_config.enabled then
		local mcp_session_store = McpSessionStore()
		local mcp_tools = {
			RuntimeStateTool(self),
			ScreenshotTool(self),
			RestartTool(),
		}
		for _, tool in ipairs(ai_tools) do
			table.insert(mcp_tools, tool)
		end
		self.mcpServer = McpServer(self.network.scheduler, mcp_tools, {
			host = mcp_config.host,
			port = mcp_config.port,
			token = mcp_config.token,
			on_tool_failure = function(name, arguments, err)
				logToolFailure(self.aiToolFailureLog, "mcp", name, arguments, err)
			end,
			session_id_generator = function()
				return mcp_session_store:generateId()
			end,
			session_store = mcp_session_store,
			server_info = {
				name = brand.name,
				version = "dev",
				description = "MCP access to the running game",
			},
		})
		local ok, err = self.mcpServer:start()
		if not ok then
			print(("MCP server failed to start: %s"):format(err))
			self.mcpServer = nil
		end
	end
	self.app:load()

	self.user_interface_manager:load()

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
	if self.mcpServer then
		self.mcpServer:stop()
	end
	if self.aiChatModel then
		self.aiChatModel:unload()
	end
	if self.needleModel then
		self.needleModel:unload()
	end
	if self.needleGpuProbe then self.needleGpuProbe:release() end
	if self.needleGpuEncoderProbe then self.needleGpuEncoderProbe:release() end
	self.network:cancelStreams("unload")
	self.seaClient:unload()
	self.previewModel:release()
	self.dlcManager:unload()
	self.library:stopThread()

	self.selectionCoordinator:unload()
	self.modifierCoordinator:unload()
	self.multiplayerController:unload()
	self.ui:unload()
	self.app:unload()
	self.persistence:unload()
end

---@param dt number
function GameController:update(dt)
	self.app:update()
	self.network:update()
	if self.needleModel then self.needleModel:update() end
	if self.needleGpuProbe then self.needleGpuProbe:update() end
	if self.needleGpuEncoderProbe then self.needleGpuEncoderProbe:update() end

	self.selectionCoordinator:update(function() self.modifierCoordinator:applySelectionModifierMeta() end)
	self.modifierCoordinator:update()

	self.joystickModel:update(dt)

	self.multiplayerController:update()
	self.gameplayInteractor:update()
	self.dlcManager:update()

	self.library:update()

	self.backgroundModel:update()
	self.previewModel:update()
	self.ui:update(dt)
end

function GameController:recreateRhythmEngine()
	if self.rhythm_engine then
		self.rhythm_engine:unload()
	end
	self.rhythm_engine = RhythmEngine(self.fs)
	self.pauseModel:setRhythmEngine(self.rhythm_engine)
end

---@param ui gui.UserInterface
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
