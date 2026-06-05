--- Tests for bancho model Player.

local Player = require("bancho.model.Player")
local GameMode = require("bancho.constants.GameMode")
local Action = require("bancho.constants.Action")
local Grade = require("bancho.constants.Grade")
local Privileges = require("bancho.constants.Privileges")
local ClientPrivileges = require("bancho.constants.ClientPrivileges")

local test = {}

function test.player_creation(t)
	local p = Player:new(1, "TestPlayer", bit.bor(Privileges.UNRESTRICTED, Privileges.VERIFIED))
	t:eq(p.id, 1)
	t:eq(p.name, "TestPlayer")
	t:eq(p.safe_name, "testplayer")
	t:assert(p.token ~= nil)
	t:eq(p.is_online, false)
end

function test.player_no_stats(t)
	local p = Player:new(1, "Test", Privileges.UNRESTRICTED)
	-- Stats are no longer stored on Player, they come from DB via stats_repo
	t:eq(p.stats, nil)
end

function test.player_status(t)
	local p = Player:new(1, "Test", Privileges.UNRESTRICTED)
	t:eq(p.status.action, Action.IDLE)
	t:eq(p.status.info_text, "")
	t:eq(p.status.map_md5, "")
	t:eq(p.status.map_id, 0)
end

function test.player_enqueue_dequeue(t)
	local p = Player:new(1, "Test", Privileges.UNRESTRICTED)
	p:enqueue("hello")
	p:enqueue("world")
	local data = p:dequeue()
	t:eq(data, "helloworld")
	-- Second dequeue returns nil
	t:eq(p:dequeue(), nil)
end

function test.player_banchoPriv(t)
	local p = Player:new(1, "Test", Privileges.UNRESTRICTED)
	t:eq(bit.band(p:bancho_priv(), ClientPrivileges.PLAYER), ClientPrivileges.PLAYER)
end

function test.player_banchoPriv_supporter(t)
	local p = Player:new(1, "Test", bit.bor(Privileges.UNRESTRICTED, Privileges.SUPPORTER))
	t:eq(bit.band(p:bancho_priv(), ClientPrivileges.SUPPORTER), ClientPrivileges.SUPPORTER)
end

function test.player_banchoPriv_moderator(t)
	local p = Player:new(1, "Test", bit.bor(Privileges.UNRESTRICTED, Privileges.MODERATOR))
	t:eq(bit.band(p:bancho_priv(), ClientPrivileges.MODERATOR), ClientPrivileges.MODERATOR)
end

function test.player_banchoPriv_developer(t)
	local p = Player:new(1, "Test", bit.bor(Privileges.UNRESTRICTED, Privileges.DEVELOPER))
	local privs = p:bancho_priv()
	t:eq(bit.band(privs, bit.bor(ClientPrivileges.DEVELOPER, ClientPrivileges.OWNER)), bit.bor(ClientPrivileges.DEVELOPER, ClientPrivileges.OWNER))
end

return test
