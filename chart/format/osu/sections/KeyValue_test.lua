local KeyValue = require("chart.format.osu.sections.KeyValue")

local test = {}

function test.basic(t)
	local key_value = KeyValue()
	key_value.keys = {"Title", "Artist"}

	local lines = {
		"Title:b",
		"Artist:d",
	}

	key_value:decode(lines)
	t:eq(key_value.Title, "b")
	t:eq(key_value.Artist, "d")
	t:tdeq(key_value:encode(), lines)
end

function test.basic_space(t)
	local key_value = KeyValue()
	key_value.space = true
	key_value.keys = {"Title", "Artist"}

	local lines = {
		"Title: b",
		"Artist: d",
	}

	key_value:decode(lines)
	t:eq(key_value.Title, "b")
	t:eq(key_value.Artist, "d")
	t:tdeq(key_value:encode(), lines)
end

return test
