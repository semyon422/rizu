--- Account management endpoints.
---
--- Handles in-game registration and difficulty rating redirects.

local IResource = require("web.framework.IResource")
local json = require("web.json")

local class = require("class")

--- Helper to send JSON response.
---@param res web.IResponse
---@param data any
local function util_send_json(res, data)
	res.headers:set("Content-Type", "application/json")
	res:send(json.encode(data))
end

---@class bancho.http.AccountResource: web.IResource
---@operator call: bancho.http.AccountResource
---@field server bancho.server.BanchoServer
local AccountResource = IResource + {}

AccountResource.routes = {
	-- In-game registration
	{"/users", {
		POST = "registerAccount",
	}},

	-- Difficulty rating redirect
	{"/difficulty-rating", {
		POST = "difficultyRating",
	}},
}

--- Domains that serve account endpoints.
AccountResource.domains = {"osu.*"}

---@param server bancho.server.BanchoServer
function AccountResource:new(server)
	self.server = server
end

--- POST /users
--- In-game registration is disabled while Bancho is being migrated to use Sea
--- as the source of truth for accounts.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function AccountResource:registerAccount(req, res, ctx)
	res.status = 400
	util_send_json(res, {
		form_error = {
			user = {
				password = {"In-game registration is disabled. Please register on the website."},
			},
		},
	})
end

--- POST /difficulty-rating
--- Redirect to osu.ppy.sh.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function AccountResource:difficultyRating(req, res, ctx)
	res.status = 307
	res.headers:set("Location", "https://osu.ppy.sh" .. ctx.parsed_uri.path)
	res:send("")
end

return AccountResource
