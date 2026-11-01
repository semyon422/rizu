local ScreenshotModel = require("rizu.app.ScreenshotModel")

---Posts what the game's parts report to a rizu.notifications.Notifications.
local GameNotifications = {}

local stage_titles = {
	scanning = "Scanning charts",
	hashing = "Hashing charts",
	difficulty = "Computing difficulty",
	scores = "Updating scores",
	hits = "Preparing scores for rescoring",
}

---A task for every scan stage. Charts that failed in it are posted as one error when it ends.
---A location scan that ends or is stopped is posted too, and so is a task that fails.
---@param notifications rizu.notifications.Notifications
---@param library rizu.library.Library
function GameNotifications.connectLibrary(notifications, library)
	local task ---@type rizu.notifications.Task?
	local stage = library.status.stage
	local errors_seen = #library.errors

	local function postErrors()
		local errors = library.errors
		local count = #errors - errors_seen
		errors_seen = #errors
		if count == 0 then return end
		notifications:post({
			kind = "error",
			type = "library_errors",
			params = {count = count},
			title = count == 1 and "A chart failed to load" or count .. " charts failed to load",
			text = tostring(errors[#errors]),
		})
	end

	---@param status rizu.library.TaskStatus
	library.onStatusChanged:add(function(status)
		if status.stage ~= stage then
			if task then notifications:endTask(task) end
			task = nil
			postErrors()
			stage = status.stage
			if stage ~= "idle" then
				task = notifications:startTask({
					type = "library_" .. stage,
					params = {stage = stage},
					title = stage_titles[stage] or ("Updating cache: " .. stage),
				})
			end
		end
		if task then
			notifications:progressTask(task, status.current, status.total > 0 and status.total or nil)
		end
	end)

	---@param id integer?
	---@return string?
	local function locationName(id)
		if not id then return end
		local location = library.locationsRepo:selectLocationById(id)
		return location and location.name or tostring(id)
	end

	---@param event {location_id: integer?, error: string}
	library.onTaskFailed:add(function(event)
		local err = event.error
		local name = locationName(event.location_id)
		notifications:post({
			kind = "error",
			type = name and "location_scan_failed" or "library_task_failed",
			params = {name = name},
			title = name and "Scan failed: " .. name or "Library task failed",
			text = err:match("^[^\n]*"),
			actions = {{id = "copy", label = "Copy details", run = function() love.system.setClipboardText(err) end}},
		})
	end)

	---@param event {location_id: integer, stopped: boolean, failed: boolean}
	library.onLocationScanned:add(function(event)
		if event.failed then return end -- posted by onTaskFailed
		local id = event.location_id
		local name = assert(locationName(id))
		if event.stopped then
			notifications:post({kind = "info", type = "location_scan_stopped", params = {name = name},
				title = "Scan stopped", text = name})
			return
		end
		library.locations:updateLocationInfo(id)
		local count = library.locations.info[id].chartfiles ---@type integer
		notifications:post({kind = "success", type = "location_scanned", params = {name = name, count = count},
			title = "Location scanned", text = ("%s: %d charts"):format(name, count)})
	end)
end

---@param notifications rizu.notifications.Notifications
---@param client rizu.OnlineClient
function GameNotifications.connectOnline(notifications, client)
	client:onChanged(function(event)
		if event.type == "login_succeeded" then
			local name = event.user and event.user.name or ""
			notifications:post({kind = "info", type = "logged_in", params = {name = name},
				title = "Logged in", text = ("Welcome back, %s!"):format(name)})
		elseif event.type == "login_failed" then
			notifications:post({kind = "error", type = "login_failed", title = "Login failed",
				text = tostring(event.error)})
		elseif event.type == "chartplay_submitted" then
			notifications:post({kind = "success", type = "score_submitted", title = "Score submitted"})
		end
	end)
end

---@param notifications rizu.notifications.Notifications
---@param screenshots rizu.ScreenshotModel
function GameNotifications.connectScreenshots(notifications, screenshots)
	---@param event {path: string}
	screenshots.onSaved:add(function(event)
		local path = event.path
		notifications:post({
			kind = "success",
			type = "screenshot_saved",
			params = {path = path},
			title = "Screenshot saved",
			text = path:match("[^/]+$"),
			actions = {{id = "open", label = "Open", run = function() ScreenshotModel.open(path) end}},
		})
	end)
end

---A UI listener that throws becomes an error with the traceback behind "Copy details".
---@param notifications rizu.notifications.Notifications
---@param api rizu.api.GameApi
function GameNotifications.connectApi(notifications, api)
	local reporting = false
	---@param event string
	---@param err string
	local function report(event, err)
		-- A failing listener of the notifications area itself would report forever.
		if reporting then return end
		reporting = true
		notifications:post({
			kind = "error",
			type = "listener_error",
			params = {event = event},
			title = "Interface error",
			text = err:match("^[^\n]*"),
			actions = {{id = "copy", label = "Copy details", run = function() love.system.setClipboardText(err) end}},
		})
		reporting = false
	end
	for _, area in pairs(api) do ---@diagnostic disable-line: no-unknown
		if type(area) == "table" and area.setErrorReporter then
			area:setErrorReporter(report)
		end
	end
end

---@param game sphere.GameController
function GameNotifications.connect(game)
	local notifications = game.notifications
	GameNotifications.connectLibrary(notifications, game.library)
	GameNotifications.connectOnline(notifications, game.online_client)
	GameNotifications.connectScreenshots(notifications, game.app.screenshotModel)
	GameNotifications.connectApi(notifications, game.api)
end

return GameNotifications
