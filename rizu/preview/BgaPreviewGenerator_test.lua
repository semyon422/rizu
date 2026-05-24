local BgaPreviewGenerator = require("rizu.preview.BgaPreviewGenerator")
local TestChartFactory = require("sea.chart.TestChartFactory")
local Note = require("chart.format.notechart.Note")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.generate_basic(t)
	local fs = FakeFilesystem()
	local generator = BgaPreviewGenerator(fs)
	local tcf = TestChartFactory()
	local res = tcf:create("4key", {})
	local chart = res.chart

	-- Set up a visual with BGA
	local visual_bga = chart.layers.main.visuals[""]
	visual_bga.bga = true

	local p1 = chart.layers.main:getPoint(1.0)
	local vp1 = visual_bga:getPoint(p1)
	local note1 = Note(vp1, "col_b", "sprite", 0)
	note1.data.images = {{"image1.png"}}
	chart.notes:insert(note1)

	local p2 = chart.layers.main:getPoint(2.0)
	local vp2 = visual_bga:getPoint(p2)
	local note2 = Note(vp2, "col_a", "sprite", 0)
	note2.data.images = {{"image2.png"}}
	chart.notes:insert(note2)

	chart:compute()
	generator:generate(chart, "test_hash")

	local encoded, err = fs:read("userdata/bga_previews/test_hash.bga_preview")
	t:assert(encoded ~= nil, err)

	local BgaPreview = require("rizu.preview.BgaPreview")
	local preview = BgaPreview()
	preview:decode(encoded)

	t:eq(#preview.samples, 2)
	-- Samples are added in order of discovery
	t:eq(preview.samples[1], "image1.png")
	t:eq(preview.samples[2], "image2.png")

	t:eq(#preview.events, 2)
	-- events are sorted by time in writePreview
	-- col_a should be 1, col_b should be 2 because "col_a" < "col_b"

	-- Note at time 1.0 (col_b)
	t:eq(preview.events[1].time, 1.0)
	t:eq(preview.events[1].column, 2) -- "col_b" is 2nd in alphabetical order

	-- Note at time 2.0 (col_a)
	t:eq(preview.events[2].time, 2.0)
	t:eq(preview.events[2].column, 1) -- "col_a" is 1st in alphabetical order
end

return test
