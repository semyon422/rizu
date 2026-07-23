local Registry = require("ui.command_palette.Registry")
local PaletteState = require("ui.command_palette.PaletteState")

local test = {}

---@param t testing.T
function test.basic_registry_and_scoping(t)
	local reg = Registry()
	reg:registerGlobal({
		id = "global.exit",
		title = "Quit Game",
		callback = function() end
	})

	reg:pushContext("results", {
		{
			id = "results.retry",
			title = "Results: Retry Song",
			callback = function() end
		}
	})

	local active = reg:getActiveCommands()
	t:eq(#active, 2)
	t:eq(active[1].id, "global.exit")
	t:eq(active[2].id, "results.retry")

	reg:popContext("results")
	active = reg:getActiveCommands()
	t:eq(#active, 1)
	t:eq(active[1].id, "global.exit")
end

---@param t testing.T
function test.state_machine_with_arguments(t)
	local reg = Registry()
	local called_speed = nil

	reg:registerGlobal({
		id = "speed",
		title = "Set Speed",
		arguments = {
			{
				name = "val",
				type = "number",
				prompt = "Enter speed multiplier:",
				validate = function(v)
					local n = tonumber(v)
					if not n or n < 0.5 then return false, "Too slow" end
					return true
				end
			}
		},
		callback = function(args)
			called_speed = args.val
		end
	})

	local state = PaletteState(reg)
	state:setQuery("speed")

	local candidates = state:getCandidates()
	t:eq(#candidates, 1)
	t:eq(candidates[1].id, "speed")

	-- Select the command
	local success, err, executed = state:confirmSelection(candidates[1])
	t:eq(success, true)
	t:eq(err, nil)
	t:eq(executed, false)
	t:eq(state:isArgumentMode(), true)
	t:eq(state:getPromptText(), "Enter speed multiplier:")

	-- Try confirming invalid value
	state:setQuery("0.1")
	success, err, executed = state:confirmSelection()
	t:eq(success, false)
	t:eq(err, "Too slow")
	t:eq(executed, false)
	t:eq(called_speed, nil)

	-- Confirm valid value
	state:setQuery("1.5")
	success, err, executed = state:confirmSelection()
	t:eq(success, true)
	t:eq(err, nil)
	t:eq(executed, true)
	t:eq(called_speed, 1.5)
	t:eq(state:isArgumentMode(), false)
end

---@param t testing.T
function test.dynamic_argument_choices(t)
	local reg = Registry()
	local choices = {
		{
			title = "First",
			value = 1,
		},
	}
	local called_value = nil

	reg:registerGlobal({
		id = "choose",
		title = "Choose Value",
		arguments = {
			{
				name = "value",
				type = "number",
				prompt = "Choose value:",
				choices = function()
					return choices
				end,
			},
		},
		callback = function(args)
			called_value = args.value
		end,
	})

	local state = PaletteState(reg)
	state:setQuery("choose")
	local success, err, executed = state:confirmSelection(state:getCandidates()[1])
	t:eq(success, true)
	t:eq(err, nil)
	t:eq(executed, false)

	choices = {
		{
			title = "Second",
			value = 2,
		},
	}

	local candidates = state:getCandidates()
	t:eq(#candidates, 1)
	t:eq(candidates[1].title, "Second")

	success, err, executed = state:confirmSelection(candidates[1])
	t:eq(success, true)
	t:eq(err, nil)
	t:eq(executed, true)
	t:eq(called_value, 2)
end

return test
