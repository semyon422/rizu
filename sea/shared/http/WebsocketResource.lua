local WebsocketPeer = require("icc.WebsocketPeer")
local NatsPeer = require("icc.nats.NatsPeer")
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

	local nats = user_connections.nats
	local inbox = "icc.inbox." .. ctx.peer_id

	-- Subscribe to our inbox for two-way call responses
	-- When callee responds to reply_to (icc.inbox.{peer_id}.{id}),
	-- this routes the response to task_handler:handleReturn() to resume the waiting coroutine
	local inbox_sid
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

	local remote_ctx = Peer(task_handler, ws_peer, nats, inbox,
		ctx.session_user, ctx.ip, ctx.port, ctx.peer_id, ctx.session)

	function ws.protocol:text(payload, fin)
		if not fin then return end

		local msg = ws_peer:decode(payload)
		if not msg then return end

		local ok, err = xpcall(task_handler.handle, debug.traceback, task_handler, ws_peer, remote_ctx, msg)
		if not ok then
			print("icc error ", err)
		end
	end

	local ok, err = ws:handshake()
	if not ok then
		res:send(tostring(err))
		return
	end

	self.domain:onConnect(remote_ctx)

	local client_task_handler = user_connections:createClientTaskHandler(remote_ctx.remote)

	-- Subscribe to NATS for server→client messages
	local peer_sid
	_, _, peer_sid = nats:subscribe("icc.peer." .. ctx.peer_id, function(nats_msg)
		local msg = ws_peer:decode(nats_msg.payload)
		if not msg then return end

		msg.reply_to = nats_msg.reply_to

		-- Two-way calls: use NatsPeer(reply_to) for response routing
		-- One-way broadcasts: ws_peer (no response sent anyway)
		local reply_peer = nats_msg.reply_to and NatsPeer(nats, nil, nats_msg.reply_to) or ws_peer
		local ok, err = xpcall(client_task_handler.handleCall, debug.traceback,
			client_task_handler, reply_peer, {}, msg)
		if not ok then
			print("nats dispatch error", err)
		end
	end)

	local ok, err = ws:loop()
	if not ok then
		print(err)
	end

	-- Cleanup NATS subscriptions (by SID to avoid clobbering other connections)
	if peer_sid then nats:unsubscribe(peer_sid) end
	if inbox_sid then nats:unsubscribe(inbox_sid) end

	self.domain:onDisconnect(remote_ctx)
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
