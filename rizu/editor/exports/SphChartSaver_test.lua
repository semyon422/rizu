local FakeFilesystem = require("fs.FakeFilesystem")
local SphChartSaver = require("rizu.editor.exports.SphChartSaver")

local test = {}

---@param t testing.T
function test.save_writes_sph_and_recomputes_library(t)
	local fs = FakeFilesystem()
	fs:createDirectory("charts")

	local chart = {
		id = "chart",
	}
	local chartmeta = {
		title = "Title",
	}
	local calls = {}
	local saver = SphChartSaver(fs, {
		chartEncoder = {
			encode = function(_, payload)
				t:eq(payload[1].chart, chart)
				t:eq(payload[1].chartmeta, chartmeta)
				return "encoded"
			end,
		},
	})

	saver:save({
		location_path = "charts/example.osu",
		dir = "charts",
		location_id = 42,
	}, {
		chart = chart,
		chartmeta = chartmeta,
		save = function()
			table.insert(calls, "save")
		end,
		genGraphs = function()
			table.insert(calls, "graphs")
		end,
	}, {
		computeLocation = function(_, dir, locationId)
			table.insert(calls, ("library:%s:%s"):format(dir, locationId))
		end,
	})

	t:tdeq(calls, {"save", "graphs", "library:charts:42"})
	t:eq(fs:read("charts/example.osu.sph"), "encoded")
end

---@param t testing.T
function test.save_errors_when_write_fails(t)
	local calls = {}
	local saver = SphChartSaver({
		write = function()
			return false
		end,
	}, {
		chartEncoder = {
			encode = function()
				return "encoded"
			end,
		},
	})

	t:has_error(function()
		saver:save({
			location_path = "charts/example.osu",
			dir = "charts",
			location_id = 42,
		}, {
			chart = {},
			chartmeta = {},
			save = function()
				table.insert(calls, "save")
			end,
			genGraphs = function()
				table.insert(calls, "graphs")
			end,
		}, {
			computeLocation = function()
				table.insert(calls, "library")
			end,
		})
	end)

	t:tdeq(calls, {"save", "graphs"})
end

return test
