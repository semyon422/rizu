local Core = require("rizu.notifications.Notifications")
local Localization = require("ui.localization.Localization")
local Notifications = require("rizu.api.Notifications")
local NotificationToasts = require("ui.views.NotificationToasts")
local Resources = require("ui.Resources")
local Screen = require("gui.Screen")

local test = {}

---@param allowed {value: boolean}
---@return rizu.notifications.Notifications store
---@return ui.views.NotificationToasts toasts
---@return gui.Screen screen
local function create(allowed)
	if not love.graphics.isActive() then assert(love.window.setMode(1600, 900)) end
	Resources.load()
	local store = Core()
	local toasts = NotificationToasts(Notifications(store), Localization(), function() return allowed.value end,
		function() end)
	local screen = Screen()
	screen.root:add(toasts)
	screen:load()
	screen:resize(1600, 900)
	return store, toasts, screen
end

---@param screen gui.Screen
---@param seconds number
local function run(screen, seconds)
	for _ = 1, math.ceil(seconds * 10) do
		screen:update(0.1)
		love.graphics.clear()
		screen:draw()
		love.graphics.present()
	end
end

---@param toasts ui.views.NotificationToasts
---@return integer
local function countToasts(toasts)
	local count = 0
	for _ in pairs(toasts.toasts) do count = count + 1 end
	return count
end

---@param t testing.T
function test.toasts_expire_merge_and_cap(t)
	local store, toasts, screen = create({value = true})
	store:post({kind = "info", type = "a", title = "A"})
	store:post({kind = "info", type = "a", title = "A"})
	t:eq(countToasts(toasts), 1)

	for i = 1, 4 do store:post({kind = "info", type = "b", title = "B" .. i}) end
	t:eq(countToasts(toasts), 3)

	run(screen, 6)
	t:eq(countToasts(toasts), 0)
	t:eq(#toasts.children, 0)
end

---@param t testing.T
function test.tasks_show_while_running_and_hide_when_not_allowed(t)
	local allowed = {value = true}
	local store, toasts, screen = create(allowed)
	local task = store:startTask({type = "library_scanning", title = "Scanning charts"})
	run(screen, 0.1)
	t:eq(#toasts.children, 1)
	t:eq((toasts.children[1] --[[@as ui.modals.notifications.NotificationItem]]).task, task)

	allowed.value = false
	store:post({kind = "info", type = "a", title = "A"})
	run(screen, 0.1)
	t:eq(#toasts.children, 0)

	allowed.value = true
	store:endTask(task)
	run(screen, 1)
	t:eq(#toasts.children, 0)
end

return test
