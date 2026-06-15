local EditorViewServices = require("rizu.editor.EditorViewServices")

local test = {}

---@param t testing.T
function test.defaults_create_view_services(t)
	local services = EditorViewServices()

	t:eq(type(services.actionService.handleHotkeys), "function")
	t:eq(type(services.audioOverlayService.getState), "function")
	t:eq(type(services.audioSettingsOverlayService.getState), "function")
	t:eq(type(services.bmsOverlayService.getBmsToolsContext), "function")
	t:eq(type(services.chartSliderService.getState), "function")
	t:eq(type(services.footerService.getState), "function")
	t:eq(type(services.infoOverlayService.getState), "function")
	t:eq(type(services.infoOverlayService.handleInput), "function")
	t:eq(type(services.notesOverlayService.getState), "function")
	t:eq(type(services.onsetsService.getOnsetsState), "function")
	t:eq(type(services.overlayActionService.setPreviewTimeToSession), "function")
	t:eq(type(services.overlayContextFactory.createInfoOverlayContext), "function")
	t:eq(type(services.overlayShellService.getState), "function")
	t:eq(type(services.scrollInputService.update), "function")
	t:eq(type(services.snapGridService.getLabels), "function")
	t:eq(type(services.timingOverlayService.getPoint), "function")
	t:eq(type(services.waveformService.update), "function")
end

---@param t testing.T
function test.dependencies_can_be_injected(t)
	local actionService = {}
	local audioOverlayService = {}
	local audioSettingsOverlayService = {}
	local bmsOverlayService = {}
	local chartSliderService = {}
	local footerService = {}
	local infoOverlayService = {}
	local notesOverlayService = {}
	local onsetsService = {}
	local overlayActionService = {}
	local overlayContextFactory = {}
	local overlayShellService = {}
	local scrollInputService = {}
	local snapGridService = {}
	local timingOverlayService = {}
	local waveformService = {}

	local services = EditorViewServices({
		actionService = actionService,
		audioOverlayService = audioOverlayService,
		audioSettingsOverlayService = audioSettingsOverlayService,
		bmsOverlayService = bmsOverlayService,
		chartSliderService = chartSliderService,
		footerService = footerService,
		infoOverlayService = infoOverlayService,
		notesOverlayService = notesOverlayService,
		onsetsService = onsetsService,
		overlayActionService = overlayActionService,
		overlayContextFactory = overlayContextFactory,
		overlayShellService = overlayShellService,
		scrollInputService = scrollInputService,
		snapGridService = snapGridService,
		timingOverlayService = timingOverlayService,
		waveformService = waveformService,
	})

	t:eq(services.actionService, actionService)
	t:eq(services.audioOverlayService, audioOverlayService)
	t:eq(services.audioSettingsOverlayService, audioSettingsOverlayService)
	t:eq(services.bmsOverlayService, bmsOverlayService)
	t:eq(services.chartSliderService, chartSliderService)
	t:eq(services.footerService, footerService)
	t:eq(services.infoOverlayService, infoOverlayService)
	t:eq(services.notesOverlayService, notesOverlayService)
	t:eq(services.onsetsService, onsetsService)
	t:eq(services.overlayActionService, overlayActionService)
	t:eq(services.overlayContextFactory, overlayContextFactory)
	t:eq(services.overlayShellService, overlayShellService)
	t:eq(services.scrollInputService, scrollInputService)
	t:eq(services.snapGridService, snapGridService)
	t:eq(services.timingOverlayService, timingOverlayService)
	t:eq(services.waveformService, waveformService)
end

return test
