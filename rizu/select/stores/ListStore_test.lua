local ListStore = require("rizu.select.stores.ListStore")

local test = {}

---A library whose worker answers only when `answer()` is called.
---@param count integer
local function createLibrary(count)
	local items = {}
	for i = 1, count do
		items[i - 1] = {chartfile_id = i}
	end
	local library = {worker = {}, requests = {}, result = {items = items, count = count}}
	library.chartviewsRepo = {
		params = {},
		unpackResult = function(_, result) return result.items, result.count, {} end,
		structToTable = function(_, struct) return {chartfile_id = struct.chartfile_id} end,
	}
	function library:enrichChartview() end
	function library:getChartviewsAsync(_, requested)
		table.insert(self.requests, {co = coroutine.running(), requested = requested})
		return coroutine.yield()
	end
	function library:answer()
		local request = table.remove(self.requests, 1)
		local chartviews = {}
		for i, item in ipairs(request.requested) do
			chartviews[i] = {chartfile_id = item.chartfile_id, title = "title " .. item.chartfile_id}
		end
		assert(coroutine.resume(request.co, chartviews))
	end
	return library
end

---@param t testing.T
function test.page_is_loaded_in_one_request(t)
	local library = createLibrary(200)
	local store = ListStore(library)
	store:setResult(library.result, "chartmetas")
	local events = {}
	store:onChanged(function(event) table.insert(events, event) end)

	local row = store:get(1)
	t:eq(row.chartfile_id, 1)
	t:eq(row.loaded, false)
	t:eq(#library.requests, 1)
	t:eq(#library.requests[1].requested, 64)

	t:eq(store:get(20), store:get(20))
	t:eq(#library.requests, 1)

	library:answer()
	t:eq(row.loaded, true)
	t:eq(row.title, "title 1")
	t:eq(store:get(64).title, "title 64")
	t:tdeq(events, {{type = "list_items_loaded", first = 1, last = 64}})
end

---@param t testing.T
function test.neighbour_page_is_loaded_ahead(t)
	local library = createLibrary(200)
	local store = ListStore(library)
	store:setResult(library.result, "chartmetas")

	store:get(40)
	t:eq(#library.requests, 2)
	t:eq(library.requests[2].requested[1].chartfile_id, 65)

	-- The last page, and the one before it because row 168 is within reach.
	store:get(200)
	t:eq(#library.requests, 4)
	t:eq(#library.requests[3].requested, 8)
end

---@param t testing.T
function test.answer_for_a_replaced_list_is_dropped(t)
	local library = createLibrary(10)
	local store = ListStore(library)
	store:setResult(library.result, "chartmetas")
	store:get(1)
	store:setResult(library.result, "chartmetas")
	local events = {}
	store:onChanged(function(event) table.insert(events, event) end)

	library:answer()
	t:eq(#events, 0)
	t:eq(store:get(1).loaded, false)
end

---@param t testing.T
function test.old_pages_are_dropped(t)
	local library = createLibrary(64 * 40)
	local store = ListStore(library)
	store.prefetch = 0
	store:setResult(library.result, "chartmetas")
	local first = store:get(1)
	for page = 1, 39 do
		store:get(page * 64 + 1)
	end
	t:eq(#library.requests, 40)
	t:ne(store:get(1), first)
	t:eq(#library.requests, 41)
end

return test
