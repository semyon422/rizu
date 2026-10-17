local bit = require("bit")
local CommandDispatcher = require("bancho.command.CommandDispatcher")
local CommandSet = require("bancho.command.CommandSet")
local Privileges = require("bancho.constants.Privileges")
local SlotStatus = require("bancho.constants.SlotStatus")

local function create_mp_dispatcher()
	local dispatcher = CommandDispatcher("!")
	require("bancho.command")(dispatcher)
	return dispatcher
end

local test = {}

function test.new(t)
	local dispatcher = CommandDispatcher("!")
	t:eq(dispatcher.prefix, "!")
	t:eq(#dispatcher.commands, 0)
	t:eq(#dispatcher.command_sets, 0)
end

function test.new_custom_prefix(t)
	local dispatcher = CommandDispatcher("/")
	t:eq(dispatcher.prefix, "/")
end

function test.register(t)
	local dispatcher = CommandDispatcher("!")
	dispatcher:register({"hello"}, function() return "hi" end, Privileges.UNRESTRICTED)
	t:eq(#dispatcher.commands, 1)
	t:eq(dispatcher.commands[1].triggers[1], "hello")
end

function test.dispatch_match(t)
	local dispatcher = CommandDispatcher("!")
	dispatcher:register({"hello"}, function(ctx) return "hi " .. ctx.args[1] end, Privileges.UNRESTRICTED)

	local result = dispatcher:dispatch(
		{ priv = Privileges.UNRESTRICTED },
		{ name = "#test" },
		"!hello world"
	)
	t:ne(result, nil)
	t:eq(result.executed, true)
	t:eq(result.response, "hi world")
end

function test.dispatch_no_match(t)
	local dispatcher = CommandDispatcher("!")
	dispatcher:register({"hello"}, function() return "hi" end, Privileges.UNRESTRICTED)

	local result = dispatcher:dispatch(
		{ priv = Privileges.UNRESTRICTED },
		{ name = "#test" },
		"!goodbye world"
	)
	t:eq(result, nil)
end

function test.dispatch_no_prefix(t)
	local dispatcher = CommandDispatcher("!")
	dispatcher:register({"hello"}, function() return "hi" end, Privileges.UNRESTRICTED)

	local result = dispatcher:dispatch(
		{ priv = Privileges.UNRESTRICTED },
		{ name = "#test" },
		"hello world"
	)
	t:eq(result, nil)
end

function test.dispatch_priv_gate(t)
	local dispatcher = CommandDispatcher("!")
	dispatcher:register({"admin"}, function() return "admin access" end, Privileges.ADMINISTRATOR)

	-- Player without admin privilege
	local result = dispatcher:dispatch(
		{ priv = Privileges.UNRESTRICTED },
		{ name = "#test" },
		"!admin"
	)
	t:eq(result, nil)

	-- Player with admin privilege
	result = dispatcher:dispatch(
		{ priv = Privileges.ADMINISTRATOR },
		{ name = "#test" },
		"!admin"
	)
	t:ne(result, nil)
	t:eq(result.response, "admin access")
end

function test.dispatch_aliases(t)
	local dispatcher = CommandDispatcher("!")
	dispatcher:register({"start", "st"}, function() return "started" end, Privileges.UNRESTRICTED)

	local result = dispatcher:dispatch(
		{ priv = Privileges.UNRESTRICTED },
		{ name = "#test" },
		"!st"
	)
	t:ne(result, nil)
	t:eq(result.response, "started")
end

function test.dispatch_subcommand(t)
	local dispatcher = CommandDispatcher("!")
	local mp_set = CommandSet:new("mp", "Multiplayer commands.")
	mp_set.commands[#mp_set.commands + 1] = {
		triggers = {"start"},
		callback = function(ctx) return "match started" end,
		priv = Privileges.UNRESTRICTED,
		hidden = false,
		doc = "Start the match",
	}
	dispatcher:registerSet(mp_set)

	local result = dispatcher:dispatch(
		{ priv = Privileges.UNRESTRICTED },
		{ name = "#multi_1" },
		"!mp start"
	)
	t:ne(result, nil)
	t:eq(result.executed, true)
	t:eq(result.response, "match started")
end

function test.dispatch_subcommand_no_match(t)
	local dispatcher = CommandDispatcher("!")
	local mp_set = CommandSet:new("mp", "Multiplayer commands.")
	mp_set.commands[#mp_set.commands + 1] = {
		triggers = {"start"},
		callback = function() return "started" end,
		priv = Privileges.UNRESTRICTED,
		hidden = false,
		doc = "Start",
	}
	dispatcher:registerSet(mp_set)

	local result = dispatcher:dispatch(
		{ priv = Privileges.UNRESTRICTED },
		{ name = "#multi_1" },
		"!mp unknown"
	)
	t:eq(result, nil)
end

function test.dispatch_context(t)
	local dispatcher = CommandDispatcher("!")
	local captured_ctx = nil
	dispatcher:register({"ctx"}, function(ctx)
		captured_ctx = ctx
		return "ok"
	end, Privileges.UNRESTRICTED)

	local player = { priv = Privileges.UNRESTRICTED, name = "test" }
	local recipient = { name = "#test" }
	dispatcher:dispatch(player, recipient, "!ctx arg1 arg2")

	t:eq(captured_ctx.player, player)
	t:eq(captured_ctx.trigger, "ctx")
	t:eq(captured_ctx.recipient, recipient)
	t:eq(#captured_ctx.args, 2)
	t:eq(captured_ctx.args[1], "arg1")
	t:eq(captured_ctx.args[2], "arg2")
end

function test.getHelp(t)
	local dispatcher = CommandDispatcher("!")
	dispatcher:register({"test"}, function() end, Privileges.UNRESTRICTED, false)
	dispatcher.commands[1].doc = "Test command"

	local help = dispatcher:getHelp({ priv = Privileges.UNRESTRICTED })
	t:ne(help:find("!test"), nil)
	t:ne(help:find("Test command"), nil)
end

function test.hasPriv(t)
	local dispatcher = CommandDispatcher("!")
	t:eq(dispatcher:hasPriv({ priv = Privileges.UNRESTRICTED }, Privileges.UNRESTRICTED), true)
	t:eq(dispatcher:hasPriv({ priv = Privileges.UNRESTRICTED }, Privileges.MODERATOR), false)
	t:eq(dispatcher:hasPriv({ priv = bit.bor(Privileges.UNRESTRICTED, Privileges.ADMINISTRATOR) }, Privileges.ADMINISTRATOR), true)
end

function test.mp_start_wrong_channel(t)
	local dispatcher = create_mp_dispatcher()
	local result = dispatcher:dispatch(
		{ priv = Privileges.UNRESTRICTED, id = 1, match = { host_id = 1, slots = {} } },
		{ name = "#general" },
		"!mp start",
		{ match_manager = { start = function() end }, players = {} }
	)
	t:eq(result.response, "Use this command in #multiplayer.")
end

function test.mp_start_requires_ready_unless_force(t)
	local dispatcher = create_mp_dispatcher()
	local match = {
		host_id = 1,
		in_progress = false,
		slots = {},
		broadcast = function() end,
	}
	for i = 0, 15 do
		match.slots[i] = {}
	end
	match.slots[0] = { player = { id = 1 }, status = SlotStatus.READY }
	match.slots[1] = { player = { id = 2 }, status = SlotStatus.NOT_READY }

	local result = dispatcher:dispatch(
		{ priv = Privileges.UNRESTRICTED, id = 1, match = match },
		{ name = "#multiplayer" },
		"!mp start",
		{ match_manager = { start = function() end }, players = {} }
	)
	t:eq(result.response, "Not all players are ready (`!mp start force` to override).")

end

function test.mp_host_invalid_target(t)
	local dispatcher = create_mp_dispatcher()
	local match = { host_id = 1, slots = {} }
	for i = 0, 15 do
		match.slots[i] = {}
	end
	match.slots[0] = { player = { id = 1, name = "Host" } }
	match.slots[1] = { player = { id = 2, name = "Guest" } }

	local result = dispatcher:dispatch(
		{ priv = Privileges.UNRESTRICTED, id = 1, match = match },
		{ name = "#multiplayer" },
		"!mp host Missing",
		{ match_manager = { transferHost = function() end }, players = {} }
	)
	t:eq(result.response, "Player not found in match.")
end

return test
