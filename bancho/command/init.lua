--- Command registry.
---
--- Imports all commands and registers them with the dispatcher.
--- Call `require("bancho.command")(dispatcher)` to populate the dispatcher.

local CommandDispatcher = require("bancho.command.CommandDispatcher")
local CommandSet = require("bancho.command.CommandSet")
local Privileges = require("bancho.constants.Privileges")
local SlotStatus = require("bancho.constants.SlotStatus")
local ServerPackets = require("bancho.protocol.ServerPackets")

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
		callback = function(ctx)
			local player = ctx.player
			local server = ctx.server
			local match = player.match
			if not server or not match then
				return "Join a match first."
			end
			if ctx.recipient.name ~= "#multiplayer" then
				return "Use this command in #multiplayer."
			end
			if match.host_id ~= player.id then
				return "Only the host can start the match."
			end
			if match.in_progress then
				return "Match already in progress."
			end
			if #ctx.args > 1 then
				return "Invalid syntax: !mp start [force]"
			end

			local force = #ctx.args == 1 and (ctx.args[1] == "force" or ctx.args[1] == "f")
			if #ctx.args == 1 and not force then
				return "Invalid syntax: !mp start [force]"
			end

			local occupied = 0
			for i = 0, 15 do
				local slot = match.slots[i]
				if slot.player ~= nil or slot.player_id ~= nil then
					occupied = occupied + 1
					if not force and occupied > 1 and slot.status ~= SlotStatus.READY then
						return "Not all players are ready (`!mp start force` to override)."
					end
				end
			end

			for i = 0, 15 do
				local slot = match.slots[i]
				if slot.player ~= nil or slot.player_id ~= nil then
					slot.status = SlotStatus.PLAYING
				end
			end

			server.match_manager:start(match)
			match:broadcast(ServerPackets.matchStart(server.match_manager:buildMatchData(match)), server.players)
			return "Good luck!"
		end,
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
