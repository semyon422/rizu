local Layer = require("ui.Layer")
local UIFactory = require("yi.UIFactory")
local Colors = require("yi.Colors")

---@class yi.Select : ui.Layer
---@overload fun(yi: yi.UserInterface): yi.Select
local Select = Layer + {}

---@param yi yi.UserInterface
function Select:new(yi)
	Layer.new(self)
	local ui = UIFactory(yi.resources)


	--[[
	self.layout = Layout({
		target_height = 1080,
		root = {id = "root", children = {
			{padding = 20, children = {{id = "content"}}},
		}}
	})
	]]

	self.title = ui:Label({
		font = "bold",
		font_size = 72,
		text = "Artist",
		box = self.layout:get("content")
	})

	self.artist = ui:Label({
		font = "bold",
		font_size = 46,
		text = "Title",
		box = self.layout:get("content")
	})

	vbox({self.title, self.artist}, {gap = -16})

	self:addArray({
		ui:Image({
			image = "select_bg_gradient",
			box = self.layout:get("root"),
			mode = "stretch",
			color = Colors.slate_900_70
		}),
		self.title,
		self.artist
	})
end

return Select
