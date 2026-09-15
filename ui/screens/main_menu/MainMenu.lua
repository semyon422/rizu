local Screen = require("gui.Screen")
local Resources = require("ui.Resources")
local Image = require("ui.views.Image")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Button = require("ui.views.Button")
local Panel = require("ui.views.Panel")
local Colors = require("ui.Colors")

---@class ui.screens.main_menu.MainMenu : gui.Screen
---@operator call: ui.screens.main_menu.MainMenu
---@field content gui.layout.FlowContainer
local MainMenu = Screen + {}

---@param ui ui.UserInterface
function MainMenu:new(ui)
	Screen.new(self)
	self.ui = ui

	self.root:setPivot(0.5, 0.5)

	self:createContent()
	self:createLogo()
	self:createButtons()
end

function MainMenu:enter()
	self.ui.command_registry:pushContext("online", self.ui.online_commands)
	self.ui.command_registry:pushContext("database", self.ui.database_commands)
	self.ui.command_registry:pushContext("package", self.ui.package_commands)
	self.root:scaleTo(1, 1, 0.4, "OutQuart")
	self.root:fadeIn(0.4, "OutQuart")
end

function MainMenu:exit()
	Screen.exit(self)
	self.ui.command_registry:popContext("online")
	self.ui.command_registry:popContext("database")
	self.ui.command_registry:popContext("package")
	self.root:scaleTo(0.95, 0.95, 0.2)
	self.root:fadeOut(0.3, "OutCubic")
	return true
end

function MainMenu:createButtons()
	local actions = FlowContainer({direction = "column", gap = 14, align = 0.5})

	local play = actions:add(Button(self.ui.localization:get("main_menu.play"), function()
		self.ui:setScreen(self.ui.song_select, true)
	end, {variant = "play", font_size = 30}))
	play:setSize(380, 88)

	local utility = actions:add(FlowContainer({direction = "row", gap = 12, align = 0.5}))
	local settings = utility:add(Button(self.ui.localization:get("main_menu.settings"), function()
		self.ui.modal_manager:attachConfig()
	end, {variant = "primary", font_size = 18}))
	settings:setSize(184, 54)
	local quit = utility:add(Button(self.ui.localization:get("main_menu.quit"), function()
		love.event.quit()
	end, {variant = "danger", font_size = 18}))
	quit:setSize(184, 54)
	utility:fitContent()

	actions:fitContent()
	self.content:add(actions)
	self.content:fitContent()

	self:createFooter()
end

function MainMenu:createFooter()
	local footer = View()
	footer:setSize(0, 72):fillWidth(0, 0):setAlignmentY(1)
	footer:add(Panel({
		color = Colors.panel,
		line_color = Colors.outline,
		lines = {top = true},
	})):anchorFill(0, 0, 0, 0)

	local links = footer:add(FlowContainer({direction = "row", gap = 12, align = 0.5}))
	local editor = links:add(Button(self.ui.localization:get("main_menu.editor"), function()
		if self.ui.game.chartSelector:chartExists() then
			self.ui:setScreen(self.ui.editor)
		else
			self.ui:setScreen(self.ui.song_select, true)
		end
	end, {font_size = 16}))
	editor:setSize(180, 44)

	local music_player = links:add(Button(self.ui.localization:get("main_menu.music_player"), function()
		self.ui:setScreen(self.ui.music_player, true)
	end, {font_size = 16}))
	music_player:setSize(180, 44)

	local locations = links:add(Button(self.ui.localization:get("main_menu.locations"), function()
		self.ui:setScreen(self.ui.locations, true)
	end, {font_size = 16}))
	locations:setSize(180, 44)

	links:fitContent()
	links:setAlignment(0.5, 0.5)
	self.root:add(footer)
end

function MainMenu:createContent()
	self.content = self.root:add(FlowContainer({direction = "column", gap = 28, align = 0.5}))
	self.content:setAlignment(0.5, 0.45)
end

function MainMenu:createLogo()
	local logo = Image(Resources.sprites.rizu, "fit")
	self.logo = logo
	self.logo:setSize(420, 161)
	self.logo:setPivot(0.5, 0.5)
	self.logo:setScale(1.08, 1.08)
	self.logo:setOpacity(0)
	self.logo:fadeIn(0.9, "OutQuint")
	self.logo:scaleTo(1, 1, 0.3, "OutQuart")
	self.content:add(logo)
end

return MainMenu
