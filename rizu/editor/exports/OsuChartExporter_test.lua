local FakeFilesystem = require("fs.FakeFilesystem")
local OsuChartExporter = require("rizu.editor.exports.OsuChartExporter")

local test = {}

---@param t testing.T
function test.export_writes_sph_osu(t)
	local fs = FakeFilesystem()
	fs:createDirectory("charts")

	local chart = {
		id = "chart",
	}
	local chartmeta = {
		title = "Title",
	}
	local calls = {}
	local exporter = OsuChartExporter(fs, {
		chartEncoder = {
			encode = function(_, payload)
				t:eq(payload[1].chart, chart)
				t:eq(payload[1].chartmeta, chartmeta)
				return "osu-encoded"
			end,
		},
	})

	exporter:export({
		location_path = "charts/example.sph",
	}, {
		chart = chart,
		chartmeta = chartmeta,
		save = function()
			table.insert(calls, "save")
		end,
	})

	t:tdeq(calls, {"save"})
	t:eq(fs:read("charts/example.sph.osu"), "osu-encoded")
end

---@param t testing.T
function test.export_errors_when_write_fails(t)
	local calls = {}
	local exporter = OsuChartExporter({
		write = function()
			return false
		end,
	}, {
		chartEncoder = {
			encode = function()
				return "osu-encoded"
			end,
		},
	})

	t:has_error(function()
		exporter:export({
			location_path = "charts/example.sph",
		}, {
			chart = {},
			chartmeta = {},
			save = function()
				table.insert(calls, "save")
			end,
		})
	end)

	t:tdeq(calls, {"save"})
end

return test
