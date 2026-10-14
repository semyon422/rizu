local FakeGameApi = require("rizu.api.fake.FakeGameApi")

local test = {}

---A fake that lacks a function crashes only the UI that calls it, and only without the game.
---@param t testing.T
function test.fake_has_every_function_of_the_real_api(t)
	for _, name in ipairs({"Charts", "Scores", "Media", "Online", "Play", "Result", "Gameplay"}) do
		local real = require("rizu.api." .. name)
		local fake = require("rizu.api.fake.Fake" .. name)
		for key, value in pairs(real) do
			if type(value) == "function" and key ~= "new" then
				t:assert(type(fake[key]) == "function", ("Fake%s:%s is missing"):format(name, key))
			end
		end
	end
end

---@param t testing.T
function test.fake_library_can_be_browsed(t)
	local api = FakeGameApi()
	local charts = api.charts
	t:eq(charts:getSetCount(), 300)
	t:eq(charts:getSelectedChart(), charts:getChart(1))

	charts:moveSet(1)
	t:eq(charts:getSelectedSetIndex(), 2)
	t:eq(api.scores:getCount(), charts:getSelectedChart().chartfile_id % 6)

	charts:setSearch("aurora 1")
	t:assert(charts:getSetCount() > 0 and charts:getSetCount() < 300)
	t:assert(charts:getSet(1).title:find("Aurora 1", 1, true))

	charts:setSearch("")
	charts:setFilterValues("original_input_mode", {"4K"})
	t:eq(charts:getActiveFilterCount(), 1)
	t:eq(charts:getSetCount(), 75)
	charts:clearFilters()

	charts:selectCollection(charts:getCollections()[3])
	t:eq(charts:getSetCount(), charts:getSelectedCollection().count)

	charts:setSearch("no such chart")
	t:eq(charts:getSetCount(), 0)
	t:eq(charts:getSelectedChart(), nil)
	t:eq(charts:canPlaySelectedChart(), false)
end

return test
