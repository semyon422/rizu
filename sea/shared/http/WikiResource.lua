local IResource = require("web.framework.IResource")
local brand = require("brand")
local markdown = require("sea.shared.markdown")

---@class sea.WikiResource: web.IResource
---@operator call: sea.WikiResource
local WikiResource = IResource + {}

---@class sea.Wiki.PageMetadata
---@field name string Localized name of the page.
---@field filename string A name of the file WITHOUT extension. A path is relative to the metadata file.

---@class sea.Wiki.CategoryMetadata
---@field name string Localized name of the category
---@field pages sea.Wiki.PageMetadata[]

---@class sea.Wiki.LanguageMetadata
---@field name string Language name
---@field code string ISO 639-1. Add country code after - if required
---@field categories sea.Wiki.CategoryMetadata[]

WikiResource.routes = {
	{"/wiki", {
		GET = "getMainPage",
	}},
	{"/wiki/:language", {
		GET = "getLanguageMainPage",
	}},
	{"/wiki/:language/:page", {
		GET = "getPage",
	}},
}

---@type sea.Wiki.LanguageMetadata[]
local language_metadatas = {
	require("sea.wiki.en-us.pages"),
	require("sea.wiki.ru.pages"),
	require("sea.wiki.ja.pages"),
	require("sea.wiki.zh.pages"),
	require("sea.wiki.zh-tw.pages")
}

---@type {[string]: sea.Wiki.LanguageMetadata }
local language_metadata_map = {}
for _, metadata in ipairs(language_metadatas) do
	language_metadata_map[metadata.code] = metadata
end

---@param views web.Views
function WikiResource:new(views)
	self.views = views
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function WikiResource:getMainPage(req, res, ctx)
	local meta = language_metadata_map["en-us"]
	local language_code = meta.code
	local page_filename = meta.categories[1].pages[1].filename
	res.status = 302
	res.headers:set("Location", ("/wiki/%s/%s"):format(language_code, page_filename))
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function WikiResource:getLanguageMainPage(req, res, ctx)
	local meta = language_metadata_map[ctx.path_params.language] or language_metadata_map["en-us"]
	local language_code = meta.code
	local page_filename = meta.categories[1].pages[1].filename
	res.status = 302
	res.headers:set("Location", ("/wiki/%s/%s"):format(language_code, page_filename))
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function WikiResource:getPage(req, res, ctx)
	local selected_language_code = ctx.path_params.language
	local meta = language_metadata_map[selected_language_code]

	if not meta then
		self:getMainPage(req, res, ctx)
		return
	end

	local selected_page ---@type string?
	local selected_page_name = ""

	for _, category in ipairs(meta.categories) do
		for _, p in ipairs(category.pages) do
			if p.filename == ctx.path_params.page then
				selected_page = p.filename
				selected_page_name = p.name
				break
			end
		end
	end

	if not selected_page then
		self:getLanguageMainPage(req, res, ctx)
		return
	end

	ctx.selected_language_code = selected_language_code
	ctx.html_lang = selected_language_code
	ctx.selected_page = selected_page
	ctx.language_metadatas = language_metadatas
	ctx.categories = meta.categories
	ctx.content_html = markdown.to_html(self.views:render(("sea/wiki/%s/%s.md"):format(selected_language_code, selected_page), ctx))

	ctx.meta_tags["title"] = ("%s - %s Wiki"):format(selected_page_name, brand.name)

	self.views:render_send(res, "sea/shared/http/wiki.etlua", ctx, true)
end

return WikiResource
