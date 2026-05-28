--- File serving endpoints for osu! client.
---
--- Serves screenshots, beatmap downloads, and .osu files.

local IResource = require("web.framework.IResource")
local json = require("web.json")

local MimeType = require("web.http.MimeType")
local http_util = require("web.http.util")

---@class bancho.http.FileResource: web.IResource
---@operator call: bancho.http.FileResource
---@field server bancho.server.BanchoServer
local FileResource = IResource + {}

FileResource.routes = {
	-- Screenshots
	{"/ss/:id.:ext", {
		GET = "getScreenshot",
	}},

	-- Beatmap downloads
	{"/d/:set_id", {
		GET = "getDownload",
	}},

	-- Beatmap files
	{"/web/maps/:filename", {
		GET = "getBeatmapFile",
	}},
}

--- Domains that serve osu! files.
FileResource.domains = {"osu.*"}

---@param server bancho.server.BanchoServer
---@param screenshots_path string
---@param beatmaps_path string
function FileResource:new(server, screenshots_path, beatmaps_path)
	self.server = server
	self.screenshots_path = screenshots_path or ".data/ss"
	self.beatmaps_path = beatmaps_path or ".data/osu"
end

--- GET /ss/{id}.{ext}
--- Serve screenshot file.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function FileResource:getScreenshot(req, res, ctx)
	local screenshot_id = ctx.path_params.id
	local extension = ctx.path_params.ext

	if not screenshot_id or not extension then
		res.status = 404
		res:send("not found")
		return
	end

	local filename = screenshot_id .. "." .. extension
	local filepath = self.screenshots_path .. "/" .. filename

	local file = io.open(filepath, "rb")
	if not file then
		res.status = 404
		res:send(json.encode({status = "Screenshot not found."}))
		return
	end

	local data = file:read("*a")
	file:close()

	local media_type = "image/png"
	if extension == "jpg" or extension == "jpeg" then
		media_type = "image/jpeg"
	end

	res.headers:set("Content-Type", media_type)
	res:send(data)
end

--- GET /d/{set_id}
--- Redirect to beatmap download.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function FileResource:getDownload(req, res, ctx)
	local set_id = ctx.path_params.set_id
	if not set_id then
		res.status = 404
		res:send("not found")
		return
	end

	local no_video = set_id:sub(-1) == "n"
	if no_video then
		set_id = set_id:sub(1, -2)
	end

	-- TODO: configure mirror download endpoint
	local mirror_url = "https://osu.ppy.sh/osu/" .. set_id
	res.status = 301
	res.headers:set("Location", mirror_url)
	res:send("")
end

--- GET /web/maps/{filename}
--- Serve .osu beatmap file.
---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function FileResource:getBeatmapFile(req, res, ctx)
	local filename = ctx.path_params.filename
	if not filename then
		res.status = 404
		res:send("not found")
		return
	end

	local filepath = self.beatmaps_path .. "/" .. filename
	local file = io.open(filepath, "rb")
	if not file then
		res.status = 404
		res:send("not found")
		return
	end

	local data = file:read("*a")
	file:close()

	res.headers:set("Content-Type", "text/plain")
	res:send(data)
end

return FileResource
