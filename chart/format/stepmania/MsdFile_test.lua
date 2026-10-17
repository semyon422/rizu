local MsdFile = require("chart.format.stepmania.MsdFile")

local test = {}

function test.basic(t)
	local msd = MsdFile()
	msd:read(table.concat({
		"// comment",
		"#q:w:e:r;",
		"#a:s;    ",
		"#z:x		",
		"#v    #b",
		"#c\r\n\t ",
	}, "\r\n"))

	t:eq(msd:getNumValues(), 5)

	t:eq(msd:getNumParams(1), 4)
	t:eq(msd:getNumParams(1000), 0)

	t:eq(msd:getParam(1, 1), "q")
	t:eq(msd:getParam(1, 1000), "")
	t:eq(msd:getParam(1000, 1), "")
	t:eq(msd:getParam(1000, 1000), "")

	t:tdeq(msd.values, {
		{"q","w","e","r"},
		{"a","s"},
		{"z","x"},
		{"v    #b"},
		{"c\r\n\t "},
	})
end

function test.unescape(t)
	-- reading #q\"w\"e;
	local msd = MsdFile()

	msd:read('#q\\"w\\"e;')
	t:eq(msd:getParam(1, 1), 'q\\"w\\"e')

	msd:read('#q\\"w\\"e;', true)
	t:eq(msd:getParam(2, 1), 'q\"w\"e')
end

function test.bom(t)
	local BOM = string.char(0xEF, 0xBB, 0xBF)

	local msd = MsdFile()

	msd:read(BOM .. "#qwe;")
	t:eq(msd:getParam(1, 1), "qwe")
end

function test.no_comment_multiline(t)
	local msd = MsdFile()

	msd:read(table.concat({
		"#q:a,  // comment",
		"s,  // comment",
		"d,  ",
		"f;",
	}, "\r\n"))

	t:eq(msd:getParam(1, 1), "q")
	t:eq(msd:getParam(1, 2), "a,  \ns,  \nd,  \r\nf")
end

return test
