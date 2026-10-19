local class = require("class")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local http_util = require("web.http.util")
local socket_url = require("socket.url")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local Resources = require("sea.app.Resources")
local Repos = require("sea.app.Repos")
local Domain = require("sea.app.Domain")
local ServerRemote = require("sea.app.remotes.ServerRemote")
local Views = require("web.framework.page.Views")
local Router = require("web.framework.router.Router")
local Sessions = require("web.framework.Sessions")
local Recaptcha = require("web.framework.Recaptcha")
local etlua = require("web.etlua")
local ServerRemoteValidation = require("sea.app.remotes.ServerRemoteValidation")
local ComputeClient = require("sea.compute.ComputeClient")
local ComputeVersion = require("sea.compute.ComputeVersion")
local ComputeJobWorker = require("sea.compute.ComputeJobWorker")
local NginxTcpSocket = require("web.nginx.NginxTcpSocket")
local brand = require("brand")
local SharedMemory = require("web.nginx.SharedMemory")
local RestyNats = require("icc.nats.RestyNats")
local NatsScope = require("sea.app.NatsScope")
local bancho_config = require("server-state.bancho_config")
local package_config = require("server-state.package_config")

---@class sea.RequestContext
---@field [any] any
---@field ip string
---@field port integer
---@field peer_id string ip:port
---@field time integer
---@field path_params {[string]: string}
---@field query {[string]: string}
---@field session_user sea.User
---@field session sea.Session?
---@field version any
---@field meta_tags {[string]: string} HTML meta tags
---@field canonical_path string Path (with query if it selects the content) used for canonical and og:url
---@field html_lang string? Value of <html lang>, "en" if not set
---@field brand sea.Brand
---@field players_online integer

---@class sea.App
---@operator call: sea.App
local App = class()

---@param app_config sea.AppConfig
function App:new(app_config)
	self.app_db = ServerSqliteDatabase(LjsqliteDatabase())
	self.sessions = Sessions("sea", app_config.sessions_secret)
	self.recaptcha = Recaptcha(app_config.recaptcha.secret_key, app_config.recaptcha.site_key, app_config.recaptcha.required_score)

	self.shared_memory = SharedMemory()

	self.repos = Repos(self.app_db.models, self.shared_memory)
	local compute_config = app_config.compute
	local compute_version = ComputeVersion.current()
	local replay_computer = ComputeClient({
		host = compute_config.host,
		port = compute_config.port,
		timeout = compute_config.timeout,
		max_payload_size = compute_config.max_payload_size,
		version = compute_version,
		socket_factory = function()
			return NginxTcpSocket()
		end,
	})
	self.domain = Domain(self.repos, app_config, LinuxFilesystem(), replay_computer, compute_version)
	self.nats_scope = NatsScope(function()
		return ngx.ctx
	end, function()
		return RestyNats()
	end)

	---@param delay number
	---@param callback fun(premature: boolean)
	---@return true?, string?
	local function schedule(delay, callback)
		return ngx.timer.at(delay, function(premature)
			self.nats_scope:call(callback, premature)
		end)
	end

	self.compute_job_worker = ComputeJobWorker(self.domain.compute_jobs, schedule, function(level, message)
		ngx.log(level == "error" and ngx.ERR or ngx.NOTICE, message)
	end)
	self.chartplay_effect_worker = ComputeJobWorker(self.domain.chartplay_effects, schedule, function(level, message)
		ngx.log(level == "error" and ngx.ERR or ngx.NOTICE, message)
	end)
	self.server_remote = ServerRemoteValidation(ServerRemote(self.domain, self.sessions))

	local whitelist = require("sea.app.remotes.whitelist")
	local client_whitelist = require("sea.app.remotes.client_whitelist")
	self.domain.user_connections:setup(self.server_remote, whitelist, client_whitelist, function()
		return self.nats_scope:get()
	end)

	local views = Views(etlua.autoload(), "sea/shared/http/layout.etlua")
	self.views = views
	self.resources = Resources(self.domain, self.server_remote, views, self.sessions, app_config, package_config, bancho_config, self.shared_memory)

	local router = Router()
	self.router = router
	router:route(self.resources:getList())

	self.domain.users.is_login_enabled = app_config.is_login_enabled
	self.domain.users.is_register_enabled = app_config.is_register_enabled

	self.resources.auth:setRecaptcha(
		self.recaptcha,
		app_config.is_login_captcha_enabled,
		app_config.is_register_captcha_enabled
	)
end

function App:load()
	self.app_db:open()
end

---@return true?
---@return string?
function App:startComputeJobWorker()
	local ok, err = self.compute_job_worker:start()
	if not ok then
		return nil, err
	end
	return self.chartplay_effect_worker:start()
end

function App:unload()
	self.compute_job_worker:stop()
	self.chartplay_effect_worker:stop()
	self.app_db:close()
end

---@param version any
---@return any
function App:setVersion(version)
	self.version = version
	return version
end

function App:getVersion()
	if self.version then
		return self.version
	end

	local p = io.popen("git log -1 --format=%H")
	if not p then
		return self:setVersion(os.time())
	end

	---@type string?
	local hash = p:read("*a"):match("^%s*(.+)%s*\n.*$")
	if not hash or #hash ~= 40 then
		return self:setVersion(os.time())
	end

	return self:setVersion(hash)
end

---@param req web.IRequest
---@param ctx sea.RequestContext
function App:handleSession(req, ctx)
	---@type sea.Session?
	local req_session = self.sessions:get(req.headers)
	if not req_session or not req_session.id then
		return
	end

	local session = self.domain.users:checkSession(req_session)
	if not session then
		return
	end

	ctx.session = session
	ctx.session_user = self.domain.users:getUser(session.user_id)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ip string
---@param port integer
function App:handle(req, res, ip, port)
	self.nats_scope:call(self.handleRequest, self, req, res, ip, port)
end

---@param req web.IRequest
---@param res web.IResponse
---@param ip string
---@param port integer
function App:handleRequest(req, res, ip, port)
	local parsed_uri = socket_url.parse(req.uri)

	-- Extract host from the Host header
	local host_header = req.headers:get("host") or ""
	-- Strip port if present (e.g. "rizu.su:8091" → "rizu.su")
	local host_name = host_header:match("^(%S+):") or host_header

	local resource, path_params, methods = self.router:getResource(parsed_uri.path, host_name)

	---@type sea.RequestContext
	local ctx = {
		parsed_uri = parsed_uri,
		path_params = path_params or {},
		query = http_util.decode_query_string(parsed_uri.query),
		ip = ip,
		port = port,
		peer_id = ip .. ":" .. port,
		time = os.time(),
		session = self.domain.users:getSession(),
		session_user = self.domain.users:getUser(),
		version = self:getVersion(),
		meta_tags = {},
		canonical_path = parsed_uri.path,
		brand = brand,
		players_online = self.domain.user_connections:getOnlineCount(),
	}

	self:handleSession(req, ctx)

	if not resource or not path_params or not methods then
		res.status = 404
		self.views:render_send(res, "sea/shared/http/not_found.etlua", ctx, true)
		res:send("")
		return
	end

	local method = req.method
	local _method = methods[method]

	if method ~= method:upper() or not resource[_method] then
		res.status = 403
		res:set_chunked_encoding()
		res:send("invalid method")
		res:send("")
		return
	end

	local ok, err = xpcall(resource[_method], debug.traceback, resource, req, res, ctx)
	if not ok then
		print(err)
		local body = ("<pre>%s</pre>"):format(err)
		res.status = 500
		res:set_chunked_encoding()
		res:send(body)
		res:send("")
		return
	end

	res:send("")
end

return App
