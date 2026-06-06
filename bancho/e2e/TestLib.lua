-- Shared helpers for Bancho E2E tests.

if not ngx then
	ngx = { log = function() end, WARN = 4, ERR = 3 }
end

local Binary = require("bancho.protocol.Binary")
local ComplexTypes = require("bancho.protocol.ComplexTypes")
local PacketReader = require("bancho.protocol.PacketReader")
local BanchoClient = require("bancho.client.BanchoClient")
local ClientConfig = require("bancho.client.ClientConfig")
local FakeHttpTransport = require("bancho.e2e.FakeHttpTransport")

local M = {}

---@param ctx bancho.e2e.E2EContext
---@param username string
---@param password_md5 string
---@param extra? table
---@return bancho.client.BanchoClient
function M.createClient(ctx, username, password_md5, extra)
	extra = extra or {}
	local config = ClientConfig {
		username = username,
		password_md5 = password_md5,
		pm_private = extra.pm_private,
		utc_offset = extra.utc_offset,
	}

	local client = BanchoClient(config)
	client.transport = FakeHttpTransport(config, function()
		return ctx:createResource()
	end)
	return client
end

---@param packets bancho.client.IncomingPacket[]
---@param id integer
---@return bancho.client.IncomingPacket?
function M.findPacket(packets, id)
	for _, pkt in ipairs(packets) do
		if pkt.id == id then
			return pkt
		end
	end
	return nil
end

---@param packets bancho.client.IncomingPacket[]
---@param id integer
---@return bancho.client.IncomingPacket?
function M.findLastPacket(packets, id)
	for i = #packets, 1, -1 do
		if packets[i].id == id then
			return packets[i]
		end
	end
	return nil
end

---@param packets bancho.client.IncomingPacket[]
---@return bancho.protocol.MultiplayerMatch?
function M.extractJoinMatch(packets)
	local pkt = M.findPacket(packets, require("bancho.protocol.ServerPackets").MATCH_JOIN_SUCCESS)
	if not pkt then return nil end
	return ComplexTypes.readMatch(PacketReader(pkt.body))
end

---@param packets bancho.client.IncomingPacket[]
---@return bancho.protocol.MultiplayerMatch?
function M.extractUpdatedMatch(packets)
	local pkt = M.findLastPacket(packets, require("bancho.protocol.ServerPackets").UPDATE_MATCH)
	if not pkt then return nil end
	return ComplexTypes.readMatch(PacketReader(pkt.body))
end

---@param packets bancho.client.IncomingPacket[]
---@return integer?
function M.extractMatchId(packets)
	local match = M.extractJoinMatch(packets)
	return match and match.id or nil
end

---@param packets bancho.client.IncomingPacket[]
---@return integer[]?
function M.extractSlotStatuses(packets)
	local match = M.extractUpdatedMatch(packets)
	return match and match.slot_statuses or nil
end

---@param packets bancho.client.IncomingPacket[]
---@return integer[]?
function M.extractSlotTeams(packets)
	local match = M.extractUpdatedMatch(packets)
	return match and match.slot_teams or nil
end

---@param packets bancho.client.IncomingPacket[]
---@return string?
function M.extractMessage(packets)
	local pkt = M.findPacket(packets, require("bancho.protocol.ServerPackets").SEND_MESSAGE)
	if not pkt then return nil end
	return ComplexTypes.readMessage(PacketReader(pkt.body)).text
end

---@param packets bancho.client.IncomingPacket[]
---@return bancho.protocol.Message?
function M.extractMessageData(packets)
	local pkt = M.findPacket(packets, require("bancho.protocol.ServerPackets").SEND_MESSAGE)
	if not pkt then return nil end
	return ComplexTypes.readMessage(PacketReader(pkt.body))
end

---@param pkt bancho.client.IncomingPacket
---@return number
function M.extractStatsAccuracy(pkt)
	local reader = PacketReader(pkt.body)
	reader:readI32()
	reader:readU8()
	reader:readString()
	reader:readString()
	reader:readI32()
	reader:readU8()
	reader:readI32()
	reader:skip(8)
	return reader:readF32()
end

---@param pkt bancho.client.IncomingPacket
---@return integer
function M.extractPresenceRank(pkt)
	local reader = PacketReader(pkt.body)
	reader:readI32()
	reader:readString()
	reader:readU8()
	reader:readU8()
	reader:readU8()
	reader:readF32()
	reader:readF32()
	return reader:readI32()
end

---@param pkt bancho.client.IncomingPacket
---@return integer[]
function M.extractFriendsList(pkt)
	local friends = Binary.readI32List(pkt.body, 1)
	return friends
end

---@param client bancho.client.BanchoClient
function M.drain(client)
	return client:ping()
end

return M
