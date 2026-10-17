require("pkg_config")
require("love.thread")

local GenerationRunner = require("rizu.mapperatorinator.GenerationRunner")

local args = {...}
local input_name = args[1] --[[@as string]]
local output_name = args[2] --[[@as string]]
local input_channel = love.thread.getChannel(input_name)
local output_channel = love.thread.getChannel(output_name)

local request = input_channel:demand() --[[@as rizu.mapperatorinator.GenerationRequest]]
local ok, err = GenerationRunner():run(request)
output_channel:push({
	type = ok and "complete" or "error",
	error = err,
	output_path = request.output_path,
})
