local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local IconTextButton = require("ui.views.IconTextButton")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local Panel = require("ui.views.Panel")
local Resources = require("ui.Resources")
local View = require("gui.View")

---A folder with charts, like a leaderboard row: a game found on this computer or a location already added.
---@class ui.screens.welcome.ChartFolderRow : gui.View
---@operator call: ui.screens.welcome.ChartFolderRow
---@field state ui.views.Label
---@field title gui.layout.FlowContainer
local ChartFolderRow = View + {}

ChartFolderRow.HEIGHT = 84

local COLOR = {Colors.surface[1], Colors.surface[2], Colors.surface[3], 0.82}
local BAR_COLOR = {0.353, 0.329, 0.408, 1}
local ICON_COLOR = {Colors.surface_raised[1], Colors.surface_raised[2], Colors.surface_raised[3], 1}
local BAR_WIDTH = 5
local TEXT_X = 99

---@class ui.screens.welcome.ChartFolderRow.Config
---@field width number
---@field name string
---@field path string
---@field icon gui.Sprite? The game's icon, a folder for a folder of no known game.
---@field added boolean
---@field add_text string
---@field added_text string
---@field on_add fun()?

---@param config ui.screens.welcome.ChartFolderRow.Config
function ChartFolderRow:new(config)
	View.new(self)
	self:setSize(config.width, ChartFolderRow.HEIGHT)
	self:add(Panel({color = COLOR})):anchorFill(0, 0, 0, 0)
	self:add(Panel({color = config.added and Colors.success or BAR_COLOR})):setSize(BAR_WIDTH, ChartFolderRow.HEIGHT)
	if config.icon then
		self:add(Image(config.icon, "fit")):setSize(64, 64):setPosition(BAR_WIDTH + 10, 10)
	else
		local square = self:add(Panel({color = ICON_COLOR}))
		square:setSize(64, 64):setPosition(BAR_WIDTH + 10, 10)
		square:add(Image(Resources.sprites.icon_folder, "native", Colors.muted)):setAlignment(0.5, 0.5):setPivot(0.5, 0.5)
	end

	local button = self:add(IconTextButton({
		text = config.added and config.added_text or config.add_text,
		icon = config.added and Resources.sprites.icon_check or Resources.sprites.icon_download,
		variant = config.added and "success" or "secondary",
		on_click = config.on_add,
	}))
	button:setAlignment(1, 0.5):setOffset(-14, 0)

	-- Long paths are cut off before the button instead of running under it.
	local text = self:add(View())
	text:setPosition(TEXT_X, 0):setSize(config.width - TEXT_X - button:getPreferredWidth() - 40, ChartFolderRow.HEIGHT)
	text:setClip(true)
	self.title = text:add(FlowContainer({direction = "row", gap = 16, align = "baseline"}))
	self.title:setPosition(0, 10)
	self.title:add(Label({font_name = "regular", font_size = 26, text = config.name}))
	self.state = self.title:add(Label({font_name = "regular", font_size = 18, text = "", color = Colors.success}))
	self.title:fitContent()
	text:add(Label({font_name = "regular", font_size = 18, text = config.path, color = Colors.muted})):setPosition(0, 46)
end

---What happens to the folder: waiting, scanning, its chart count.
---@param text string
---@param color gui.Color?
function ChartFolderRow:setState(text, color)
	self.state:setText(text)
	self.state.color = color or Colors.success
	self.title:fitContent()
end

return ChartFolderRow
