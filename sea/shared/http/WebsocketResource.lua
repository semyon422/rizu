local WebsocketPeer = require("icc.WebsocketPeer")
local Message = require("icc.Message")
local IResource = require("web.framework.IResource")
local Websocket = require("web.ws.Websocket")
local Peer = require("sea.app.Peer")

---@class sea.WebsocketResource: web.IResource
---@operator call: sea.WebsocketResource
local WebsocketResource = IResource + {}

WebsocketResource.routes = {
	{"/ws", {
		GET = "server",
	}},
	{"/ws.html", {
		GET = "client",
	}},
}

---@param domain sea.Domain
---@param views web.Views
function WebsocketResource:new(domain, views)
	self.domain = domain
	self.views = views
	self.user_connections = domain.user_connections
	self.task_handler = self.user_connections.task_handler
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function WebsocketResource:server(req, res, ctx)
	local ws = Websocket(req.soc, req, res, "server")
	local ws_peer = WebsocketPeer(ws)
	local task_handler = self.task_handler
	local user_connections = self.user_connections

	ws.max_payload_len = 1e7
	task_handler.timeout = 60

	local nats = user_connections:getNats()
	local inbox = "icc.inbox." .. ctx.peer_id

	-- Subscribe to our inbox for two-way call responses
	-- When callee responds to reply_to (icc.inbox.{peer_id}.{id}),
	-- this routes the response to task_handler:handleReturn() to resume the waiting coroutine
	local _, inbox_sid = nil, nil
	_, _, inbox_sid = nats:subscribe(inbox .. ".*", function(nats_msg)
		local id = tonumber(nats_msg.subject:match("^.+%.(%d+)$"))
		if not id then return end

		local decoded = ws_peer:decode(nats_msg.payload)
		if not decoded then return end

		---@type icc.Message
		local msg = setmetatable({
			id = id,
			ret = true,
			n = decoded.n or 0,
		}, {__index = Message})
		for i = 1, msg.n do
			msg[i] = decoded[i]
		end

		task_handler:handleReturn(msg)
	end)
	-- inbox_sid is nil when NATS is unavailable; two-way ICC calls will error immediately

	local peer = Peer(task_handler, ws_peer, nats, inbox, ctx.session_user, ctx.ip, ctx.port, ctx.peer_id, ctx.session)

	function ws.protocol:text(payload, fin)
		if not fin then return end

		local msg = ws_peer:decode(payload)
		if not msg then return end

		local ok, err = xpcall(task_handler.handle, debug.traceback, task_handler, ws_peer, peer, msg)
		if not ok then
			print("icc error ", err)
		end
	end

	local ok, err = ws:handshake()
	if not ok then
		res:send(tostring(err))
		return
	end

	local client_task_handler = user_connections:createClientTaskHandler(peer.remote)
	peer:setup_dispatch(client_task_handler)

	-- Subscribe BEFORE onConnect so broadcasts reach this peer
	peer:subscribe("icc.peer." .. ctx.peer_id)
	peer:subscribe("icc.broadcast.all")

	self.domain:onConnect(peer)

	local ok, err = ws:loop()
	if not ok then
		print(err)
	end

	-- Cleanup NATS subscriptions (by SID to avoid clobbering other connections)
	if inbox_sid then nats:unsubscribe(inbox_sid) end
	for _, sid in pairs(peer.broadcast_sids) do
		nats:unsubscribe(sid)
	end

	self.domain:onDisconnect(peer)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function WebsocketResource:client(req, res, ctx)
	local vc = "aqua/web/ws/test.html"
	ctx.url = "ws://127.0.0.1:8180/ws"
	local s = self.views:render(vc, ctx)

	res.headers:set("Content-Type", "text/html")
	res:send(s)
end

return WebsocketResource
