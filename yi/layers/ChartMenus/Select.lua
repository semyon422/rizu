local Screen = require("yi.Screen")
local S = require("gui.composition.Strategies")
local UIFactory = require("yi.UIFactory")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local string_util = require("string_util")

local ChartInfo = require("yi.views.info.ChartInfo")
local ChartDifficulty = require("yi.views.info.ChartDifficulty")
local GameplayState = require("yi.views.info.GameplayState")
local IconButton = require("yi.views.IconButton")
local SetList = require("yi.views.select.SetList")
local ChartList = require("yi.views.select.ChartList")
local SpringValue = require("gui.anim.SpringValue")

local ChartPreviewView = require("sphere.views.SelectView.ChartPreviewView")

local SelectCommands = require("yi.layers.ChartMenus.SelectCommands")

---@class yi.Select : yi.Screen
---@overload fun(yi: yi.UserInterface): yi.Select
local Select = Screen + {}

local GAP = 20

---@param yi yi.UserInterface
function Select:new(yi)
	Screen.new(self)
	self.yi = yi

	local ui = UIFactory()

	self.title = ui:Label({
		font = "bold",
		font_size = 72,
		text = "Artist",
		color = Colors.text,
	})

	self.artist = ui:Label({
		font = "bold",
		font_size = 46,
		text = "Title",
		color = Colors.text,
	})

	self.creator = ui:Label({
		font = "regular",
		font_size = 24,
		text = "Creator • (optional) Etterna pack",
		color = Colors.text_muted
	})
	self.creator.y = 4

	self.chart_info = ChartInfo()
	self.chart_diff = ChartDifficulty(yi)
	self.gameplay_state = GameplayState()
	self.gameplay_state.y = -9
	self.set_list = SetList(self.yi.game.chartSelector)
	self.chart_list = ChartList(self.yi.game.chartSelector, self.yi.game.settings_config)
	self.chart_list.x = GAP

	self.chart_preview_view = ChartPreviewView(yi.game)

	self.zoom = SpringValue({value = 1})

	local button_back = function()
		self.yi:setScreen("main_menu")
	end

	local button_config = function()
		self.yi:setScreen("config")
	end

	local button_modifiers = function()
		self.yi.modals:open("modifiers")
	end

	local button_input = function()
		self.yi.modals:open("input")
	end

	local button_filters = function()
		self.yi.modals:open("filters")
	end

	local button_noteskins = function()
		self.yi.modals:open("noteskins")
	end

	local button_scores = function()
		self.yi.modals:open("scores")
	end

	self.root = S.Stack({
		S.Track({
			space = {"*", 2, 64},
			S.Stack({ -- Inner container
				ui:Image({
					image = "select_bg_gradient",
					fit_box = true,
					color = Colors.select_bg_gradient
				}),

				S.Anchor({
					pivot = {1, 0},
					self.set_list,
				}),

				S.Anchor({
					pivot = {0, 0.5},
					self.chart_list
				})
			}),
			ui:Rectangle({
				fit_box = true,
				color = Colors.line
			}),
			S.Stack({
				ui:Rectangle({
					fit_box = true,
					color = Colors.select_side_panel_bg
				}),
				S.Stack({
					padding = {0, 10, 10, 0},
					S.Track({
						direction = "column",
						gap = 10,
						align = 0.5,
						IconButton(Resources.quads.icon_note),
						IconButton(Resources.quads.icon_folder),
						IconButton(Resources.quads.icon_download),
						ui:Rectangle({
							width = 64,
							height = 2,
							fit_box = false,
							color = Colors.line
						}),
						IconButton(Resources.quads.icon_gear, button_config),
						IconButton(Resources.quads.icon_funnel, button_filters),
						IconButton(Resources.quads.icon_sparkles, button_modifiers),
						IconButton(Resources.quads.icon_keyboard, button_input),
						IconButton(Resources.quads.icon_palette, button_noteskins),
						IconButton(Resources.quads.icon_trophy, button_scores),
					}),
					S.Anchor({
						pivot = {0.5, 1},
						IconButton(Resources.quads.icon_chevron_left, button_back),
					})
				})
			})
		}),
		S.Stack({
			padding = GAP,
			S.Column({
				self.title,
				self.artist,
				self.creator
			}),
			S.Anchor({
				pivot = {0, 1},
				S.Flow({
					direction = "column",
					gap = 10,
					S.Flow({
						direction = "row",
						gap = 20,
						align = 1,
						self.chart_diff,
						ui:Rectangle({
							width = 3,
							height = 80,
							fit_box = false,
							color = Colors.line,
							blend_mode = "add"
						}),
						self.gameplay_state
					}),
					ui:Rectangle({
						width = 900,
						height = 3,
						fit_box = false,
						color = Colors.line,
						blend_mode = "add"
					}),
					self.chart_info
				}),
			})
		}),
	})

	local cv = self.yi.game.chartSelector.chartview
	if cv then
		self:onChartviewUpdate(cv)
	end

	self.gameplay_state:bind(self.yi.game.replayBase, self.yi.game.timeRateModel)
	self.commands = SelectCommands(self.yi.game)
end

function Select:load()
	Screen.load(self)
	self.chart_preview_view:load()
	self.yi.game.chartSelector.onChanged:add(self)
	self.yi.game.chartSelector.state.onChanged:add(self)
end

function Select:unload()
	self.yi.game.chartSelector.onChanged:remove(self)
	self.yi.game.chartSelector.state.onChanged:remove(self)
end

function Select:enter()
	self.yi.command_registry:pushContext("select", self.commands)
	self.chart_list:slideIn()
end

function Select:exit()
	self.yi.command_registry:popContext("select")
	self.yi.modals:close()
end

function Select:update(dt)
	self.chart_preview_view:update(dt)
	Screen.update(self, dt)
end

function Select:draw()
	love.graphics.push("all")
	self.chart_preview_view:draw()
	love.graphics.pop()
	Screen.draw(self)
end

---@param cv rizu.library.Chartview
function Select:onChartviewUpdate(cv)
	if not cv.hash then
		return
	end
	self.chart_info:bind(cv, self.yi.game.replayBase)
	self.chart_diff:bind(cv, self.yi.game.timeRateModel:get())
	self.title:setText(cv.title or "Unknown Title")
	self.artist:setText(cv.artist or "Unknown Artist")

	local creator = cv.creator
	if not creator or creator == "" then
		creator = nil
	end

	if cv.format == "stepmania" then
		local path = cv.path or "Unknown Path"
		local spl = string_util.split(path, "/")
		local pack = spl[1] or "Unknown Path"
		if creator then
			self.creator:setText(("%s • %s"):format(creator, pack))
		else
			self.creator:setText(("%s"):format(pack))
		end
	elseif creator then
		self.creator:setText(creator)
	end
end

function Select:updateInfo()
	local cv = self.yi.game.chartSelector.chartview
	self:onChartviewUpdate(cv)
	self.gameplay_state:bind(self.yi.game.replayBase, self.yi.game.timeRateModel)
end

function Select:handleKeyDown(key)
	if key == "escape" then
		self.yi:setScreen("main_menu")
	elseif key == "return" then
		self.yi:setScreen("chart_loading")
	elseif key == "c" then
		self.yi:setScreen("config")
	elseif key == "j" then
		self.yi.game.chartSelector:scrollLevel(1, 1)
	elseif key == "k" then
		self.yi.game.chartSelector:scrollLevel(1, -1)
	elseif key == "h" then
		self.yi.game.chartSelector:scrollLevel(2, -1)
	elseif key == "l" then
		self.yi.game.chartSelector:scrollLevel(2, 1)
	elseif key == "[" then
		self.yi.game.timeRateModel:increase(-1)
		self.yi.game.modifierSelectModel:change()
		self:updateInfo()
	elseif key == "]" then
		self.yi.game.timeRateModel:increase(1)
		self.yi.game.modifierSelectModel:change()
		self:updateInfo()
	elseif key == "m" then
		self.yi.modals:open("modifiers")
	elseif key == "i" then
		self.yi.modals:open("input")
	elseif key == "f" then
		self.yi.modals:open("filters")
	elseif key == "n" then
		self.yi.modals:open("noteskins")
	else
		return false
	end

	return true
end

function Select:receive(event)
	if event.type == "chartview" then --- TODO: Why is this 'type' when it should be 'name'?
		self:onChartviewUpdate(event.chartview)
		return
	end

	if event.type == "selection" and event.level == 1 then
		self.chart_list:slideIn()
		return
	end

	self.chart_preview_view:receive(event)
	Screen.receive(self, event)
end

return Select
