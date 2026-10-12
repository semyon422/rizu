local class = require("class")
local bass = require("bass")
local FakeGameApi = require("rizu.api.fake.FakeGameApi")

---Runs a user interface on `rizu.api.fake.FakeGameApi` instead of the game.
---Takes the game's place in the loop.
---@class rizu.api.fake.Preview
---@operator call: rizu.api.fake.Preview
local Preview = class()

---@param ui_class rizu.app.UserInterface
function Preview:new(ui_class)
	self.ui_class = ui_class
end

function Preview:load()
	assert(love.window.setMode(1600, 900, {resizable = true}))
	love.window.setTitle("UI preview")
	-- UI sounds play through BASS.
	bass.init()
	if tonumber(bass.BASS_GetDevice()) < 0 then bass.init(0) end

	-- The background needs the window, so the fake game starts here.
	self.api = FakeGameApi()
	self.ui = self.ui_class({api = self.api} --[[@as sphere.GameController]], "")
	self.ui:load()
end

---@param event {name: string, time: number, [integer]: any}
function Preview:receive(event)
	if event.name == "update" then
		self.api:update(event[1])
		self.ui:update(event[1])
	elseif event.name == "draw" then
		self.ui:draw()
	elseif event.name == "quit" then
		self.ui:unload()
	else
		self.ui:receive(event)
	end
end

return Preview
