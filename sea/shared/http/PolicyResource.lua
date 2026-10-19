local IResource = require("web.framework.IResource")
local brand = require("brand")
local markdown = require("sea.shared.markdown")

---@class sea.PolicyResource: web.IResource
---@operator call: sea.PolicyResource
local PolicyResource = IResource + {}

PolicyResource.routes = {
	{"/policies", {
		GET = "getPage",
	}},
}

---@param views web.Views
---@param responsible_person {name: string, email: string}
function PolicyResource:new(views, responsible_person)
	self.views = views
	self.responsible_person = responsible_person
	self.policies = {
		{
			key = "terms",
			name = "Terms of Use",
			filename = "sea/shared/http/terms_of_use.md"
		},
		{
			key = "privacy",
			name = "Privacy Policy",
			filename = "sea/shared/http/privacy_policy.md"
		},
		{
			key = "dmca",
			name = "Copyright (DMCA)",
			filename = "sea/shared/http/dmca.md",
		}
	}
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function PolicyResource:getPage(req, res, ctx)
	local policy_key = ctx.query.policy_key or "terms"

	ctx.policies = self.policies
	ctx.selected_policy_key = policy_key

	for _, v in ipairs(self.policies) do
		if v.key == policy_key then
			ctx.policy_filename = v.filename
			ctx.meta_tags["title"] = ("%s - %s"):format(v.name, brand.name)
		end
	end

	ctx.responsible_person = self.responsible_person

	if not ctx.policy_filename then
		ctx.policy_filename = self.policies[1].filename
	else
		ctx.canonical_path = "/policies?policy_key=" .. policy_key
	end

	ctx.content_html = markdown.to_html(self.views:render(ctx.policy_filename, ctx))

	self.views:render_send(res, "sea/shared/http/policies.etlua", ctx, true)
end

return PolicyResource
