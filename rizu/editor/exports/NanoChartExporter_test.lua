local FakeFilesystem = require("fs.FakeFilesystem")
local NanoChartExporter = require("rizu.editor.exports.NanoChartExporter")

local test = {}

local function createNote(column, _type, weight, time)
	return {
		column = column,
		type = _type,
		weight = weight,
		visualPoint = {
			point = {
				absoluteTime = time,
			},
		},
	}
end

local function createChart(notes)
	return {
		inputMode = {
			key = 4,
			getInputMap = function()
				return {
					key1 = 1,
					key2 = 2,
					scratch1 = 5,
				}
			end,
		},
		notes = {
			iter = function()
				return ipairs(notes)
			end,
		},
	}
end

---@param t testing.T
function test.export_writes_nanochart_and_previews(t)
	local fs = FakeFilesystem()
	fs:createDirectory("charts")

	local capturedHash
	local capturedInputs
	local capturedNotes
	local chartEncoderChart
	local chartEncoderChartmeta
	local chart = createChart({
		createNote("key2", "tap", 0, 2),
		createNote("key1", "hold", 1, 1.25),
		createNote("key1", "hold", -1, 3),
		createNote("scratch1", "tap", 0, 4),
		createNote("key3", "mine", 0, 5),
	})
	local chartmeta = {
		title = "Title",
	}
	local calls = {}
	local exporter = NanoChartExporter(fs, {
		nanoChart = {
			encode = function(_, hash, inputs, notes)
				capturedHash = hash
				capturedInputs = inputs
				capturedNotes = notes
				return "nano-data"
			end,
		},
		chartEncoder = {
			encodeSph = function(_, encodedChart, encodedChartmeta)
				chartEncoderChart = encodedChart
				chartEncoderChartmeta = encodedChartmeta
				return {
					sphLines = {
						encode = function()
							return {"line-a", "line-b"}
						end,
					},
				}
			end,
		},
		sphPreview = {
			encodeLines = function(_, lines, version)
				table.insert(calls, "preview:" .. tostring(version or 0) .. ":" .. table.concat(lines, ","))
				return "preview-" .. tostring(version or 0)
			end,
		},
		compress = function(data)
			return "compressed:" .. data
		end,
	})
	local editorModel = {
		chart = chart,
		chartmeta = chartmeta,
		save = function()
			table.insert(calls, "save")
		end,
	}

	exporter:export({real_path = "charts/example"}, editorModel)

	t:eq(#capturedHash, 16)
	t:eq(capturedInputs, 4)
	t:tdeq(capturedNotes, {
		{time = 1.25, type = 1, input = 1},
		{time = 2, type = 1, input = 2},
	})
	t:eq(chartEncoderChart, chart)
	t:eq(chartEncoderChartmeta, chartmeta)
	t:tdeq(calls, {
		"save",
		"preview:0:line-a,line-b",
		"preview:1:line-a,line-b",
	})
	t:eq(fs:read("charts/example.nanochart"), "nano-data")
	t:eq(fs:read("charts/example.nanochart_compressed"), "compressed:nano-data")
	t:eq(fs:read("charts/example.preview0"), "preview-0")
	t:eq(fs:read("charts/example.preview0_compressed"), "compressed:preview-0")
	t:eq(fs:read("charts/example.preview1"), "preview-1")
	t:eq(fs:read("charts/example.preview1_compressed"), "compressed:preview-1")
end

---@param t testing.T
function test.export_errors_when_write_fails(t)
	local exporter = NanoChartExporter({
		write = function()
			return false
		end,
	}, {
		nanoChart = {
			encode = function()
				return "nano-data"
			end,
		},
		chartEncoder = {
			encodeSph = function()
				error("preview should not be encoded after nanochart write failure")
			end,
		},
		compress = function(data)
			return data
		end,
	})
	local calls = {}

	t:has_error(function()
		exporter:export({real_path = "charts/example"}, {
			chart = createChart({}),
			chartmeta = {},
			save = function()
				table.insert(calls, "save")
			end,
		})
	end)

	t:tdeq(calls, {"save"})
end

return test
