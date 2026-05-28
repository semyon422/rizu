--- Command registry.
---
--- Imports all commands and registers them with the dispatcher.
--- Call `require("bancho.command")(dispatcher)` to populate the dispatcher.

local CommandDispatcher = require("bancho.command.CommandDispatcher")
local CommandSet = require("bancho.command.CommandSet")
local Privileges = require("bancho.constants.Privileges")

--- Register all commands with the given dispatcher.
---@param dispatcher bancho.command.CommandDispatcher
return function(dispatcher)
	-- Register the help command
	dispatcher:register(
		{"help", "h", ""},
		function(ctx)
			return ctx._dispatcher:getHelp(ctx.player)
		end,
		Privileges.UNRESTRICTED,
		true
	)

	-- Create multiplayer command set
	local mp_set = CommandSet:new("mp", "Multiplayer commands.")
	mp_set.commands[#mp_set.commands + 1] = {
		triggers = {"start", "st"},
		callback = function() return "mp start not yet implemented" end,
		priv = Privileges.UNRESTRICTED,
		hidden = false,
		doc = "Start the match",
	}
	mp_set.commands[#mp_set.commands + 1] = {
		triggers = {"abort", "a"},
		callback = function() return "mp abort not yet implemented" end,
		priv = Privileges.UNRESTRICTED,
		hidden = false,
		doc = "Abort the match",
	}
	mp_set.commands[#mp_set.commands + 1] = {
		triggers = {"map"},
		callback = function() return "mp map not yet implemented" end,
		priv = Privileges.UNRESTRICTED,
		hidden = false,
		doc = "Change match map",
	}
	mp_set.commands[#mp_set.commands + 1] = {
		triggers = {"host"},
		callback = function() return "mp host not yet implemented" end,
		priv = Privileges.UNRESTRICTED,
		hidden = false,
		doc = "Transfer match host",
	}
	mp_set.commands[#mp_set.commands + 1] = {
		triggers = {"mods"},
		callback = function() return "mp mods not yet implemented" end,
		priv = Privileges.UNRESTRICTED,
		hidden = false,
		doc = "Set match mods",
	}
	mp_set.commands[#mp_set.commands + 1] = {
		triggers = {"freemods", "fm"},
		callback = function() return "mp freemods not yet implemented" end,
		priv = Privileges.UNRESTRICTED,
		hidden = false,
		doc = "Toggle freemods",
	}
	mp_set.commands[#mp_set.commands + 1] = {
		triggers = {"invite", "inv"},
		callback = function() return "mp invite not yet implemented" end,
		priv = Privileges.UNRESTRICTED,
		hidden = false,
		doc = "Invite player to match",
	}
	dispatcher:registerSet(mp_set)
end
