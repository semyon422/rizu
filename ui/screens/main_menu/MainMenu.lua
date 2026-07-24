local Screen = require("gui.Screen")
local Resources = require("ui.Resources")
local Registry = require("ui.command_palette.Registry")
local PaletteState = require("ui.command_palette.PaletteState")
local GlobalCommands = require("ui.command_palette.GlobalCommands")
local OnlineCommands = require("ui.commands.OnlineCommands")
local DatabaseCommands = require("ui.commands.DatabaseCommands")
local CommandPalette = require("ui.views.CommandPalette")
local Image = require("ui.views.Image")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Button = require("ui.views.Button")

---@class ui.screens.main_menu.MainMenu : gui.Screen
---@operator call: ui.screens.main_menu.MainMenu
local MainMenu = Screen + {}

---@param ui ui.UserInterface
function MainMenu:new(ui)
	Screen.new(self)
	self.ui = ui

	self.root:setPivot(0.5, 0.5)
	self.root.handles_keyboard_input = true
	self.root.onKeyDown = function(root, e)
		if e.key == ";" and love.keyboard.isDown("lshift", "rshift") then
			self.palette:show()
		end
	end

	local registry = Registry()
	for _, command in ipairs(GlobalCommands.get(ui.game, ui)) do
		registry:registerGlobal(command)
	end

	registry:pushContext("online", OnlineCommands(ui.game))
	registry:pushContext("database", DatabaseCommands(ui.game))
	self.palette = CommandPalette(PaletteState(registry), function() end)

	self:createLogo()
	self:createButtons()
	self.root:add(self.palette)
end

function MainMenu:enter()
	self.root:scaleTo(1, 1, 0.4, "OutQuart")
	self.root:fadeIn(0.4, "OutQuart")
end

function MainMenu:exit()
	Screen.exit(self)
	self.root:scaleTo(0.95, 0.95, 0.2)
	self.root:fadeOut(0.3, "OutCubic")
	return true
end

function MainMenu:createButtons()
	local buttons = FlowContainer({
		direction = "column",
		gap = 16
	})

	buttons:add(Button("Play", function()
		self.ui:setScreen(self.ui.song_select, true)
	end))

	buttons:add(Button("Settings", function()
	end))

	buttons:add(Button("Quit", function()
		love.event.quit()
	end))

	buttons:fitContent()
	buttons:setAlignment(0.5, 0.5)
	buttons:setOffset(0, 170)

	self.root:add(buttons)
end

function MainMenu:createLogo()
	local logo = Image(Resources.atlas, Resources.quads.rizu)
	self.logo = logo
	self.logo:setAlignment(0.5, 0.5)
	self.logo:setScale(0.7, 0.7)
	self.logo:setPivot(0.5, 0.5)
	self.logo:setOpacity(0)
	self.logo:setOffset(0, -170)
	self.logo:fadeIn(0.9, "OutQuint")
	self.logo:moveTo(0, -200, 0.5, "OutCubic")
	self.root:add(logo)
end

return MainMenu
