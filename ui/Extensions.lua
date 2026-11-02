---Plugins that extend the default user interface. A plugin adds a function from its `require` module, and
---the interface calls it with itself once its screens and commands exist, at every load. There it can
---register screens (ui.screen_manager:register), push command contexts (ui.command_registry:pushContext)
---and patch screens. It requires nothing, so the module of a plugin can add itself in any thread.
local Extensions = {}

---@type fun(ui: ui.UserInterface)[]
Extensions.list = {}

---@param extend fun(ui: ui.UserInterface)
function Extensions.add(extend)
	table.insert(Extensions.list, extend)
end

return Extensions
