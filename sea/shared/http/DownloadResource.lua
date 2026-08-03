local IResource = require("web.framework.IResource")
local brand = require("brand")

---@class sea.DownloadResource: web.IResource
---@operator call: sea.DownloadResource
local DownloadResource = IResource + {}

DownloadResource.routes = {
	{"/download", {
		GET = "getPage",
	}},
}

---@param views web.Views
---@param repo_url string
function DownloadResource:new(views, repo_url)
	self.views = views
	self.repo_url = repo_url
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function DownloadResource:getPage(req, res, ctx)
	ctx.repo_url = self.repo_url
	ctx.meta_tags["title"] = "Download " .. brand.name
	ctx.meta_tags["description"] = "It's available for Windows, MacOS, and Linux! Follow the instructions to install and start playing!"
	self.views:render_send(res, "sea/shared/http/download.html", ctx, true)
end

return DownloadResource
