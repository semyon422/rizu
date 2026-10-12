local bass = require("bass")
local FakeGameApi = require("rizu.api.fake.FakeGameApi")
local UserInterface = require("ui.UserInterface")

local test = {}

local modifiers = {control = false, shift = false, alt = false, super = false}

---The default user interface on the fake game: load it, browse, click everything in reach.
---Passing means nothing in it still needs the real game to stay alive.
---@param t testing.T
function test.song_select_runs_without_the_game(t)
	if not love.graphics.isActive() then assert(love.window.setMode(1600, 900)) end
	bass.init(0)

	local api = FakeGameApi()
	local ui = UserInterface({api = api} --[[@as sphere.GameController]], "")
	ui:load()

	local time = 0
	---@param count integer
	local function frames(count)
		for _ = 1, count do
			time = time + 1 / 60
			api:update(1 / 60)
			ui:update(1 / 60)
			love.graphics.origin()
			ui:draw()
		end
	end
	---@param key string
	local function press(key)
		ui:receive({name = "keypressed", key, key, false, time = time}, modifiers)
		frames(1)
		ui:receive({name = "keyreleased", key, key, time = time}, modifiers)
		frames(1)
	end
	---@param x number
	---@param y number
	local function click(x, y)
		ui:receive({name = "mousemoved", x, y, 0, 0, time = time}, modifiers)
		ui:receive({name = "mousepressed", x, y, 1, time = time}, modifiers)
		frames(1)
		ui:receive({name = "mousereleased", x, y, 1, time = time}, modifiers)
		frames(1)
	end

	frames(30)
	t:eq(ui.screen_manager.input_screen, ui.song_select)

	local charts = api.charts
	for _, key in ipairs({"down", "down", "right", "left", "up", "j", "k", "return", "escape", "f1", "tab"}) do
		press(key)
	end
	charts:selectSet(250)
	frames(20)
	charts:setSearch("cascade")
	frames(5)
	charts:setYesNoFilter("played", "yes")
	charts:setSort("artist")
	charts:selectCollection(charts:getCollections()[4])
	frames(5)
	charts:setSearch("no such chart")
	frames(5)
	t:eq(charts:getSetCount(), 0)
	charts:setSearch("")
	charts:clearFilters()
	charts:selectCollection(nil)
	api.scores:setSource("online")
	api.play:changeRate(3)
	frames(5)

	-- A grid over the whole window reaches every button, list and control at least once.
	local width, height = love.graphics.getDimensions()
	for y = 10, height - 10, 60 do
		for x = 10, width - 10, 160 do
			click(x, y)
		end
	end
	ui:receive({name = "wheelmoved", 0, -3, time = time}, modifiers)
	frames(30)

	t:assert(charts:getSetCount() > 0)
	ui:unload()
end

return test
