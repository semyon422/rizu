local GameplayChart = require("rizu.gameplay.GameplayChart")
local Settings = require("rizu.config.Settings")
local ReplayBase = require("sea.replays.ReplayBase")
local ComputeContext = require("sea.compute.ComputeContext")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local chartfile_name = "chart.sph"
local chartfile_data = [[
# metadata
title Title
artist Artist
name Name
creator Creator
audio audio.mp3
input 4key

# notes
1000 =0
0100
0010
0001
1000 =4
]]

---@param t testing.T
function test.all(t)
	local fs = FakeFilesystem()
	local settings = Settings.createConfig(fs)

	local dir = "chart_set"
	local chartview = {
		location_dir = dir,
		location_path = dir .. "/" .. chartfile_name,
		chartfile_name = chartfile_name,
		index = 1,
	}

	fs:createDirectory(dir)
	fs:write(chartview.location_path, chartfile_data)

	local gl = GameplayChart(settings, fs, chartview)

	gl:load(ReplayBase(), ComputeContext())
end

return test
