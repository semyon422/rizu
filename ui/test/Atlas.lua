local View = require("gui.View")
local Resources = require("ui.Resources")

---@class ui.test.AtlasView : gui.View
---@operator call: ui.test.AtlasView
local AtlasView = View + {}

function AtlasView:draw()
	local atlas_count = #Resources.atlases
	if atlas_count == 0 then
		return
	end

	local slot_width = self.width / atlas_count
	for index, atlas in ipairs(Resources.atlases) do
		local atlas_width, atlas_height = atlas:getDimensions()
		local scale = math.min(slot_width / atlas_width, self.height / atlas_height)
		local x = (index - 1) * slot_width + (slot_width - atlas_width * scale) / 2
		local y = (self.height - atlas_height * scale) / 2
		love.graphics.draw(atlas, x, y, 0, scale, scale)
	end
end

---@type ui.test.TestCase
local case = {
	name = "image atlases",
	build = function(root)
		root:add(AtlasView()):anchorFill(0, 0, 0, 0)
	end,
}

return case
