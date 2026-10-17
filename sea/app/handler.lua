local pprint = require("pprint")
pprint.colored = false
pprint.export()

local App = require("sea.app.App")

local app_config = require("server-state.app_config")

---@type sea.App
local app

local function init()
	app = App(app_config)
	app:load()
end

local function init_worker()
	if ngx.worker.id() ~= 0 then
		return
	end
	if not app then
		init()
	end
	assert(app:startComputeJobWorker())
end

---@param req web.IRequest
---@param res web.IResponse
---@param ip string
---@param port integer
local function handler(req, res, ip, port)
	if not app then
		init()
	end
	app:handle(req, res, ip, port)
end

return {
	handle = handler,
	init_worker = init_worker,
}
