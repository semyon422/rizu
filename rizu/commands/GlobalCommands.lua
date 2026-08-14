-- Builds the list of unique resolutions from the allowed display modes.
---@return rizu.command.Fuzzy.Candidate[] choices
local function getResolutionChoices()
	---@type {[string]: boolean}
	local seen = {}
	---@type rizu.command.Fuzzy.Candidate[]
	local choices = {}
	---@type {width: number, height: number}[]
	local modes = love.window.getFullscreenModes()
	for _, mode in ipairs(modes) do
		local key = mode.width .. "x" .. mode.height
		if not seen[key] then
			seen[key] = true
			table.insert(choices, {
				title = key,
				value = key,
			})
		end
	end
	table.sort(choices, function(a, b)
		local a_h = tonumber(a.value:match("x(%d+)$"))
		local b_h = tonumber(b.value:match("x(%d+)$"))
		if a_h ~= b_h then
			return a_h < b_h
		end
		local a_w = tonumber(a.value:match("^(%d+)x"))
		local b_w = tonumber(b.value:match("^(%d+)x"))
		return a_w < b_w
	end)
	return choices
end

-- Returns the list of globally accessible commands.
---@param game sphere.GameController
---@return rizu.command.Command[]
return function(game)
	return {
		{
			id = "global.needle",
			title = "Needle",
			description = "Turn natural language into a safe game command",
			arguments = {{
				name = "query",
				type = "string",
				prompt = "Needle:",
			}},
			callback = function() end,
		},
		{
			id = "global.exit",
			title = "Quit/Exit Game",
			description = "Exits the game immediately",
			callback = function()
				love.event.quit()
			end,
		},
		{
			id = "global.screenshot",
			title = "Screenshot: Capture",
			description = "Captures a screenshot",
			callback = function()
				game.app.screenshotModel:capture(false)
			end,
		},
		{
			id = "global.screenshot_open",
			title = "Screenshot: Capture and Open",
			description = "Captures a screenshot and opens it in the file manager",
			callback = function()
				game.app.screenshotModel:capture(true)
			end,
		},
		{
			id = "global.set_resolution",
			title = "Set Resolution",
			description = "Sets the window resolution from the allowed display modes",
			arguments = {{
				name = "resolution",
				type = "string",
				prompt = "Select resolution:",
				choices = function()
					return getResolutionChoices()
				end,
			}},
			callback = function(args)
				local val = tostring(args.resolution)
				local w, h = val:match("^(%d+)x(%d+)$")
				local width = assert(tonumber(w), "invalid resolution: " .. val)
				local height = assert(tonumber(h), "invalid resolution: " .. val)
				game.app.windowModel:setResolution(width, height)
				game.persistence.configModel:write("settings")
			end,
		},
	}
end
