local class = require("class")
local Library = require("rizu.library.Library")
local TestChartFactory = require("sea.chart.TestChartFactory")
local FunctionTimer = require("time.FunctionTimer")

---@class rizu.select.TestLibraryFactory
---@operator call: rizu.select.TestLibraryFactory
local TestLibraryFactory = class()

function TestLibraryFactory:new()
	self.tcf = TestChartFactory()
end

local LinuxFilesystem = require("fs.LinuxFilesystem")

function TestLibraryFactory:create()
	local fs = LinuxFilesystem()
	local timer = FunctionTimer(function()
		return 0
	end)
	local lib = Library(fs, fs:getWorkingDirectory(), timer)
	lib.database:load(":memory:")
	lib.chartviewsRepo:setSync(true)

	-- Mock locations so it doesn't try to access filesystem
	lib.locations.load = function() end

	return lib
end

---@param lib rizu.library.Library
---@param data table
function TestLibraryFactory:populate(lib, data)
	-- Insert location
	local loc = lib.locationsRepo:selectLocation("charts")
	if not loc then
		loc = lib.locationsRepo:insertLocation({
			path = "charts", name = "test", is_relative = true, is_internal = true,
		})
	end

	for _, entry in ipairs(data) do
		-- Insert chartfile_set if not exists
		local set_id = entry.chartfile_set_id
		local set = lib.database.models.chartfile_sets:find({id = set_id})
		if not set then
			lib.database.models.chartfile_sets:create({
				id = set_id,
				location_id = loc.id,
				name = entry.set_name or ("Set " .. set_id),
				dir = entry.set_dir or ("dir" .. set_id),
				modified_at = 0,
				is_file = false,
			})
		end

		-- Insert chartfile
		local chartfile_id = entry.chartfile_id
		lib.database.models.chartfiles:create({
			id = chartfile_id,
			set_id = set_id,
			name = entry.chartfile_name or ("chart" .. chartfile_id .. ".sph"),
			path = entry.path or ("path" .. chartfile_id),
			hash = entry.hash or ("hash" .. chartfile_id),
			modified_at = 0,
		})

		-- Insert chartmeta
		local chartmeta = self.tcf:createChartmeta(entry)
		lib.database.models.chartmetas:create(chartmeta)

		-- Insert chartdiff
		local chartdiff = self.tcf:createChartdiff(entry)
		lib.database.models.chartdiffs:create(chartdiff)
	end
end

---@param lib rizu.library.Library
---@param data table
function TestLibraryFactory:createScore(lib, data)
	local chartplay = self.tcf:createChartplay(data)
	return lib.database.models.chartplays:create(chartplay)
end

return TestLibraryFactory
