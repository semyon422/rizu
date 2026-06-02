local Container = require("ui.Container")
local TabButton = require("yi.views.config_list.TabButton")
local Painter = require("yi.Painter")

---@class yi.ConfigTopBar : ui.Container
---@operator call: yi.ConfigTopBar
---@field children yi.ConfigTabButton[]
local ConfigTopBar = Container + {}

---@param resources yi.Resources
---@param tabs string[]
---@param on_tab_change fun(tab_index: integer)
function ConfigTopBar:new(resources, tabs, on_tab_change)
	Container.new(self)
	self.resources = resources

	local font = self.resources:getFont("bold", 24)
	self.text_batch = love.graphics.newTextBatch(font)

	for i, v in ipairs(tabs) do
		table.insert(
			self.children,
			TabButton(resources, self.text_batch, v, function(tab)
				self:deactivateAllTabs()
				tab.active = true
				on_tab_change(i)
			end))
	end

	self.children[1].active = true
end

function ConfigTopBar:deactivateAllTabs()
	for _, v in ipairs(self.children) do
		v.active = false
	end
end

function ConfigTopBar:setTabActive(index)
	local tab = self.children[index]
	if tab then
		self:deactivateAllTabs()
		tab.active = true
	end
end

function Container:load()
	local gap = 12
	local y = (self.box.height - self.children[1]:getHeight()) / 2
	local x = y

	for _, v in ipairs(self.children) do
		v:setPosition(x, y)
		x = x + v:getWidth() + gap
	end
end

local lg = love.graphics

function ConfigTopBar:draw()
	local atlas, quads = self.resources.atlas, self.resources.quads

	local w = self.box.width
	local _, _, iw, ih = quads.pill_cap:getViewport()
	local cap_scale = self.box.height / ih
	lg.setColor(1, 1, 1, 0.7)
	lg.push()
	lg.scale(cap_scale)
	lg.draw(atlas, quads.pill_cap)
	lg.draw(atlas, quads.pixel, iw, 0, 0, w / cap_scale - iw * 2, ih)
	lg.draw(atlas, quads.pill_cap, w / cap_scale, 0, 0, -1, 1)
	lg.pop()

	self.text_batch:clear()
	Container.draw(self)
	Painter.snapToPixel()
	lg.draw(self.text_batch)
end

return ConfigTopBar
