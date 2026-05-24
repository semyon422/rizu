local Source = require("rizu.engine.audio.bass.Source")
local ChartAudio = require("rizu.engine.audio.ChartAudio")
local Decoder = require("rizu.engine.audio.bass.Decoder")
local SoftwareMixer = require("rizu.engine.audio.SoftwareMixer")
local ChartFactory = require("chart.format.notechart.ChartFactory")
local LoveFilesystem = require("fs.LoveFilesystem")
local ResourceLoader = require("rizu.files.ResourceLoader")
local ResourceFinder = require("rizu.files.ResourceFinder")
local Wave = require("audio.Wave")

local bass = require("bass")

local cf = ChartFactory()

local test = {}

do return test end

bass.init()

function test.bms()
	local fs = LoveFilesystem()
	local rf = ResourceFinder(fs)
	local rl = ResourceLoader(fs, rf)

	-- local dir = "userdata/charts/Touhou bms pack/Nativefaith"
	-- local path = dir .. "/native_h.bme"
	-- local dir = "userdata/charts/local_test/[ginkiha] EOS"
	-- local path = dir .. "/eos_5h.bms"
	local dir = "userdata/charts/local_test/Brightness"
	local path = dir .. "/BLA_10n.bme"
	local chart = assert(cf:getCharts(path, assert(fs:read(path))))[1].chart

	local ca = ChartAudio()
	ca:load(chart, true)

	rf:addPath(dir)
	rl:load(chart.resources)

	---@type rizu.audio.bass.Decoder[]
	local decoders = {}
	for i, sound in ipairs(ca.sounds) do
		local data = rl:getResource(sound.name)
		if data then
			decoders[i] = Decoder(data)
		end
	end

	local mixer = SoftwareMixer(ca.sounds, decoders)

	-- local wave = Wave()
	-- wave:initBuffer(mixer:getChannelCount(), mixer.end_pos / 4)
	-- mixer:getData(wave.byte_ptr, mixer.end_pos)
	-- fs:write("out.wav", wave:encode())
	-- do return end

	mixer:setPosition(0)

	local source = Source(mixer)
	source:play()

	local a = false
	while true do
		local time = love.timer.getTime()
		source:update()
		print(source:getPosition(), love.timer.getTime() - time)
		-- if source:getPosition() > 10 and not a then
		-- 	a = true
		-- 	source:setPosition(40)
		-- end
		love.timer.sleep(0.1)
	end

	source:release()
end

return test
