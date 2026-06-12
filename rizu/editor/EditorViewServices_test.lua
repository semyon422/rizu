local EditorViewServices = require("rizu.editor.EditorViewServices")

local test = {}

---@param t testing.T
function test.defaults_create_view_services(t)
	local services = EditorViewServices()

	t:eq(type(services.actionService.handleHotkeys), "function")
	t:eq(type(services.overlayActionService.setPreviewTimeToSession), "function")
	t:eq(type(services.scrollInputService.update), "function")
end

---@param t testing.T
function test.dependencies_can_be_injected(t)
	local actionService = {}
	local overlayActionService = {}
	local scrollInputService = {}

	local services = EditorViewServices({
		actionService = actionService,
		overlayActionService = overlayActionService,
		scrollInputService = scrollInputService,
	})

	t:eq(services.actionService, actionService)
	t:eq(services.overlayActionService, overlayActionService)
	t:eq(services.scrollInputService, scrollInputService)
end

return test
