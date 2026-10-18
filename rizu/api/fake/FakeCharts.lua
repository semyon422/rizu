local Events = require("rizu.api.Events")

---`rizu.api.Charts` over a made-up library, see that file for what each function does.
---@class rizu.api.fake.FakeCharts : rizu.api.Events
---@operator call: rizu.api.fake.FakeCharts
---@field sets rizu.api.Chart[][] The sets in the list, each an array of its charts.
local FakeCharts = Events + {}

local titles = {"Aurora", "Blue Hour", "Cascade", "Daybreak", "Ember", "Fathom", "Glasswork", "Halcyon"}
local artists = {"Nine Lanterns", "Paper Kites", "Quiet Harbor", "Red Meridian"}
local names = {"Easy", "Normal", "Hard", "Insane"}
local inputmodes = {"4key", "7key", "7key1scratch", "10key"}
local formats = {"osu", "quaver", "stepmania", "bms"}
local sort_names = {"title", "artist", "difficulty", "duration"}
local PACKS = 5

---@param sets_count integer?
function FakeCharts:new(sets_count)
	Events.new(self)
	---@type rizu.api.Chart[][]
	self.all_sets = {}
	local id = 0
	for i = 1, sets_count or 300 do
		local set = {}
		for j = 1, (i - 1) % 4 + 1 do
			id = id + 1
			local difficulty = j * 5 + i % 7
			set[j] = {
				loaded = true,
				chartfile_set_id = i, chartfile_id = id, chartmeta_id = id, chartdiff_id = id, chartplay_id = 0,
				hash = ("%032x"):format(id), index = 1,
				title = ("%s %d"):format(titles[(i - 1) % #titles + 1], i),
				artist = artists[(i - 1) % #artists + 1],
				name = names[j], creator = "fake",
				inputmode = inputmodes[(i - 1) % #inputmodes + 1],
				format = formats[(i - 1) % #formats + 1],
				chartmeta_mode = "mania", mode = "mania",
				level = j * 3, duration = 90 + i % 120, notes_count = 400 * j + i,
				tempo = 120 + i % 80, tempo_avg = 120 + i % 80, tempo_min = 120, tempo_max = 200,
				long_notes_ratio = (i % 10) / 10,
				enps_diff = difficulty, osu_diff = difficulty / 4, msd_diff = difficulty, user_diff = difficulty,
				difficulty = difficulty,
				accuracy = i % 3 == 0 and 0.02 or nil,
				lamp = false,
				set_dir = ("packs/Pack %d"):format((i - 1) % PACKS + 1),
				location_path = "fake",
			}
		end
		self.all_sets[i] = set
	end

	---@type rizu.api.Collection[]
	self.collections = {
		{kind = "library", name = "/", label = "/", depth = 0, count = #self.all_sets},
		{kind = "collection", name = "packs", label = "packs", depth = 1, count = #self.all_sets, path = "packs"},
	}
	for i = 1, PACKS do
		local name = ("Pack %d"):format(i)
		local count = math.floor((#self.all_sets - i) / PACKS) + 1
		table.insert(self.collections, {
			kind = "collection", name = name, label = "packs/" .. name, depth = 2, count = count, path = "packs/" .. name,
		})
	end
	self.collection = self.collections[1]

	self.search = ""
	self.lamp_search = ""
	self.sort = "title"
	self.yes_no = {played = "any", scratch = "any"}
	self.values = {format = {}, original_input_mode = {}, actual_input_mode = {}}
	self.set_index = 0
	self.chart_index = 0
	self.sets = {}
	self:refresh()
end

---@private
---@param filter rizu.api.Charts.YesNoFilter
---@param has boolean
---@return boolean
function FakeCharts:matchesYesNo(filter, has)
	local value = self.yes_no[filter]
	return value == "any" or (value == "yes") == has
end

---@private
---@param filter rizu.api.Charts.ValueFilter
---@param text string
---@return boolean
function FakeCharts:matchesValues(filter, text)
	local values = self.values[filter]
	if #values == 0 then return true end
	for _, value in ipairs(values) do
		local keys = value:match("^(%d+)K$")
		if keys and text:find("^" .. keys .. "key") or text == value then return true end
	end
	return false
end

---@private
---@param chart rizu.api.Chart
---@return boolean
function FakeCharts:matches(chart)
	local path = self.collection.path
	return (self.search == "" or (chart.title .. " " .. chart.artist):lower():find(self.search:lower(), 1, true) ~= nil)
		and (not path or chart.set_dir:sub(1, #path) == path)
		and self:matchesYesNo("played", chart.accuracy ~= nil)
		and self:matchesYesNo("scratch", chart.inputmode:find("scratch") ~= nil)
		and self:matchesValues("format", chart.format)
		and self:matchesValues("original_input_mode", chart.inputmode)
		and self:matchesValues("actual_input_mode", chart.inputmode)
end

function FakeCharts:refresh()
	self.random_history = nil
	self:emit("sets_loading")
	local selected = self:getSelectedChart()
	local sets = {}
	for _, set in ipairs(self.all_sets) do
		if self:matches(set[1]) then sets[#sets + 1] = set end
	end
	local sort = self.sort
	table.sort(sets, function(a, b)
		if a[1][sort] ~= b[1][sort] then return a[1][sort] < b[1][sort] end
		return a[1].chartfile_set_id < b[1].chartfile_set_id
	end)
	self.sets = sets
	self.set_index = #sets > 0 and 1 or 0
	for i, set in ipairs(sets) do
		if selected and set[1].chartfile_set_id == selected.chartfile_set_id then self.set_index = i end
	end
	self:emit("sets_changed")
	self:setChartIndex(selected and selected.chartfile_set_id == (self:getSet(self.set_index) or {}).chartfile_set_id
		and self.chart_index or 1)
end

---@private
---@param index integer
function FakeCharts:setChartIndex(index)
	local set = self.sets[self.set_index] or {}
	self.chart_index = math.max(math.min(index, #set), #set > 0 and 1 or 0)
	self:emit("charts_changed")
	self:emit("selection_changed", self:getSelectedChart())
	self:emit("can_play_changed")
end

function FakeCharts:getSetCount() return #self.sets end
function FakeCharts:getSet(index) return self.sets[index] and self.sets[index][1] end
function FakeCharts:getSelectedSetIndex() return self.set_index end

function FakeCharts:selectSet(index)
	index = math.max(1, math.min(index, #self.sets))
	if #self.sets == 0 or index == self.set_index then return end
	self.set_index = index
	self:setChartIndex(1)
end

function FakeCharts:moveSet(offset) self:selectSet(self.set_index + offset) end
function FakeCharts:selectRandomSet()
	local from = self.set_index
	self:selectSet(math.random(1, math.max(#self.sets, 1)))
	if self.set_index ~= from and from > 0 then
		self.random_history = self.random_history or {}
		table.insert(self.random_history, from)
	end
end

function FakeCharts:undoRandomSet()
	local index = table.remove(self.random_history or {})
	if index then self:selectSet(index) end
end

function FakeCharts:getChartCount() return #(self.sets[self.set_index] or {}) end
function FakeCharts:getChart(index) return (self.sets[self.set_index] or {})[index] end
function FakeCharts:getSelectedChartIndex() return self.chart_index end

function FakeCharts:selectChart(index)
	index = math.max(1, math.min(index, self:getChartCount()))
	if self:getChartCount() == 0 or index == self.chart_index then return end
	self.chart_index = index
	self:emit("selection_changed", self:getSelectedChart())
end

function FakeCharts:moveChart(offset) self:selectChart(self.chart_index + offset) end
function FakeCharts:getSelectedChart() return self:getChart(self.chart_index) end
function FakeCharts:announceSelection() self:emit("selection_changed", self:getSelectedChart()) end
function FakeCharts:canPlaySelectedChart() return self:getSelectedChart() ~= nil end

function FakeCharts:isLoading() return false end
function FakeCharts:getSearch() return self.search end

function FakeCharts:setSearch(text)
	self.search = text
	self:refresh()
end

function FakeCharts:getLampSearch() return self.lamp_search end

function FakeCharts:setLampSearch(text)
	self.lamp_search = text
	self:refresh()
end

function FakeCharts:getSortNames() return sort_names end
function FakeCharts:getSort() return self.sort end

function FakeCharts:setSort(name)
	self.sort = name
	self:refresh()
end

function FakeCharts:getYesNoFilter(filter) return self.yes_no[filter] end

function FakeCharts:setYesNoFilter(filter, value)
	self.yes_no[filter] = value
	self:emit("filters_changed")
	self:refresh()
end

function FakeCharts:getFilterValues(filter) return self.values[filter] end

function FakeCharts:setFilterValues(filter, values)
	self.values[filter] = values
	self:emit("filters_changed")
	self:refresh()
end

function FakeCharts:getActiveFilterCount()
	local count = 0
	for _, value in pairs(self.yes_no) do
		if value ~= "any" then count = count + 1 end
	end
	for _, values in pairs(self.values) do
		if #values > 0 then count = count + 1 end
	end
	return count
end

function FakeCharts:clearFilters()
	self.yes_no = {played = "any", scratch = "any"}
	self.values = {format = {}, original_input_mode = {}, actual_input_mode = {}}
	self:emit("filters_changed")
	self:refresh()
end

function FakeCharts:getCollections() return self.collections end
function FakeCharts:getSelectedCollection() return self.collection end

function FakeCharts:selectCollection(collection)
	self.collection = collection or self.collections[1]
	self:emit("collections_changed")
	self:refresh()
end

function FakeCharts:getLocationsInCollections() return self.locations_in_collections or false end

function FakeCharts:setLocationsInCollections(enabled)
	self.locations_in_collections = enabled
	self:emit("collections_changed")
end

function FakeCharts:checkLibraryEmpty(f) f(#self.all_sets == 0) end

function FakeCharts:getSource() return self.source or "local" end

function FakeCharts:setSource(source)
	self.source = source
	self:emit("source_changed")
end

function FakeCharts:getOnlineError() return nil end

return FakeCharts
