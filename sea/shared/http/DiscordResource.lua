local IResource = require("web.framework.IResource")
local brand = require("brand")

---@class sea.DiscordResource: web.IResource
---@operator call: sea.DiscordResource
local DiscordResource = IResource + {}

DiscordResource.routes = {
	{"/discord", {
		GET = "get",
	}},
}

---@param req web.IRequest
---@param res web.IResponse
function DiscordResource:get(req, res)
	res.status = 302
	res.headers:set("Location", brand.discord_url)
end

return DiscordResource
