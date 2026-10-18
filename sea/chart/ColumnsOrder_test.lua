local ColumnsOrder = require("sea.chart.ColumnsOrder")

local test = {}

---@param t testing.T
function test.identity(t)
	local co = ColumnsOrder("4key2fx")
	t:eq(co:export(), nil)
end

---@param t testing.T
function test.mirror(t)
	local co = ColumnsOrder("4key2fx")
	t:tdeq(co:mirror():export(), {4, 3, 2, 1, 6, 5})
	t:eq(co:getName(), "mirror")
	t:eq(co:mirror():export(), nil)
end

---@param t testing.T
function test.mirror_half(t)
	local co = ColumnsOrder("7key")
	t:tdeq(co:mirror("left"):export(), {3, 2, 1, 4, 5, 6, 7})
	t:eq(co:getName(), "mirror left")
	co = ColumnsOrder("7key")
	t:tdeq(co:mirror("right"):export(), {1, 2, 3, 4, 7, 6, 5})
	t:eq(co:getName(), "mirror right")
end

---@param t testing.T
function test.shift(t)
	local co = ColumnsOrder("4key2fx")
	t:tdeq(co:shift(1):export(), {4, 1, 2, 3, 6, 5})
	t:tdeq(co:shift(-2):export(), {2, 3, 4, 1, 6, 5})
	t:eq(co:shift(1):export(), nil)

	local co = ColumnsOrder("4key")
	t:eq(co:getName(), nil)
	t:eq(co:shift(1):getName(), "shift 1")
	t:eq(co:shift(1):getName(), "shift 2")
	t:eq(co:shift(1):getName(), "shift -1")
	t:eq(co:shift(1):getName(), nil)

	local co = ColumnsOrder("5key")
	t:eq(co:getName(), nil)
	t:eq(co:shift(1):getName(), "shift 1")
	t:eq(co:shift(1):getName(), "shift 2")
	t:eq(co:shift(1):getName(), "shift -2")
	t:eq(co:shift(1):getName(), "shift -1")
	t:eq(co:shift(1):getName(), nil)
end

---@param t testing.T
function test.shift_complex(t)
	local co = ColumnsOrder("4key3fx")
	t:eq(co:getName(), nil)
	t:eq(co:shift(1):getName(), "shift 1")
	t:eq(co:shift(1):getName(), "shift 2")
	for i = 1, 8 do
		t:eq(co:shift(1):getName(), "custom")
	end
	t:eq(co:shift(1):getName(), "shift -1")
	t:eq(co:shift(1):getName(), nil)
end

---@param t testing.T
function test.bracketswap(t)
	t:tdeq(ColumnsOrder("4key"):bracketswap():export(), {1, 3, 2, 4})
	t:tdeq(ColumnsOrder("5key"):bracketswap():export(), {2, 1, 3, 5, 4})
	t:tdeq(ColumnsOrder("7key"):bracketswap():export(), {1, 3, 2, 4, 6, 5, 7})
	t:tdeq(ColumnsOrder("8key"):bracketswap():export(), {1, 3, 2, 4, 5, 7, 6, 8})
	t:tdeq(ColumnsOrder("9key"):bracketswap():export(), {1, 3, 2, 4, 5, 6, 8, 7, 9})
	t:tdeq(ColumnsOrder("10key"):bracketswap():export(), {1, 4, 2, 5, 3, 8, 6, 9, 7, 10})
	t:tdeq(ColumnsOrder("11key"):bracketswap():export(), {1, 4, 2, 5, 3, 6, 9, 7, 10, 8, 11})
	t:tdeq(ColumnsOrder("12key"):bracketswap():export(), {1, 4, 2, 5, 3, 6, 7, 10, 8, 11, 9, 12})
end

---@param t testing.T
function test.random(t)
	local values = t:assert(ColumnsOrder("10key"):random():export())
	table.sort(values)
	t:eq(table.concat(values), "12345678910")

	values = t:assert(ColumnsOrder("14key2scratch"):random():export())
	table.sort(values)
	t:eq(table.concat(values), "12345678910111213141516")

	values = t:assert(ColumnsOrder("14key2scratch"):random("left"):export())
	table.sort(values)
	t:eq(table.concat(values), "12345678910111213141516")

	values = t:assert(ColumnsOrder("14key2scratch"):random("right"):export())
	table.sort(values)
	t:eq(table.concat(values), "12345678910111213141516")
end

---@param t testing.T
function test.import_export(t)
	local co = ColumnsOrder("4key", {2, 3, 4, 1})
	t:tdeq(co:export(), {2, 3, 4, 1})
end

---@param t testing.T
function test.partial_apply(t)
	local co = ColumnsOrder("4key")
	co:apply({key1 = "key4", key4 = "key1"})
	t:tdeq(co:export() or {}, {4, 2, 3, 1})
end

return test
