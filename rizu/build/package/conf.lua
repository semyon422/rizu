---@diagnostic disable

local love_run = love.run

function love.run()
	local fileData = assert(love.filesystem.newFileData("game.love"))
	assert(love.filesystem.mount(fileData, ""))

	package.loaded.main = nil
	package.loaded.conf = nil

	love.run = love_run
	love.conf = nil
	love.handlers = nil
	love.init()
	if love.load then
		love.load(love.arg.parseGameArguments(arg), arg)
	end
	assert(love.run, "love.run is not defined")
	local loop = love.run()

	return function() return loop() end
end

function love.conf(t)
	t.audio = nil
	t.window = nil
	t.modules = {}
end
