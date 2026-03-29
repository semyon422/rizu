local IUserInterface = require("sphere.IUserInterface")
local Context = require("yi.Context")
local View = require("yi.views.View")
local Inputs = require("ui.input.Inputs")
local Resources = require("yi.Resources")
local Engine = require("yi.Engine")
local LoveTimer = require("time.LoveTimer")
local Background = require("yi.views.Background")
local Screens = require("yi.views.Screens")
local Modals = require("yi.views.Modals")

---@class yi.UserInterface : sphere.IUserInterface
---@overload fun(game: sphere.GameController): yi.UserInterface
local UserInterface = IUserInterface + {}

UserInterface.gameView = {} -- For imgui modals

local MAX_DT = 1 / 30

---@param game sphere.GameController
function UserInterface:new(game)
	self.game = game

	self.resources = Resources()
	self.inputs = Inputs()
	self.ctx = Context(self.game, self.inputs, self.resources)
	self.engine = Engine(self.inputs, self.ctx, LoveTimer())
	self.engine.target_height = 1080
	self.engine.check_dimensions_during_update = true
end

function UserInterface:load()
	self.resources:load()

	local root = self.engine.root

	local background = root:add(Background())
	local screens = root:add(Screens())
	local modals = root:add(Modals())
	local top = root:add(View()) -- Cursor, Tooltip, Notifications, Dropdown items

	self.ctx:setLayers(background, screens, modals, top)
	self.engine:load()

	screens:set("menu")

	self.screens = screens
end

---@param dt number
function UserInterface:update(dt)
	local capped_dt = math.min(dt, MAX_DT)
	self.engine:update(capped_dt, love.mouse.getPosition())
end

function UserInterface:draw()
	self.engine:draw()
end

---@param event table
function UserInterface:receive(event)
	self.screens:receive(event) -- :sob:
	self.engine:receive(event)
end

return UserInterface
