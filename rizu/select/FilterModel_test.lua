local FilterModel = require("rizu.select.FilterModel")

local test = {}

local function createModel(selected_filters)
	return FilterModel({configs = {
		select = {selected_filters = selected_filters or {}},
		filters = {notechart = {}},
	}})
end

---@param t testing.T
function test.applies_dynamic_input_modes(t)
	local model = createModel()
	model:setInputModes("original input mode", {"7K", "14key2scratch"})
	model:setInputModes("actual input mode", {"10K", "88key"})
	model:apply()

	t:tdeq(model.combined_filters, {
		{"or", {chartdiff_inputmode__startswith = "10key"}, {chartdiff_inputmode = "88key"}},
		{"or", {inputmode = "14key2scratch"}, {inputmode__startswith = "7key"}},
	})
end

---@param t testing.T
function test.emits_when_filters_are_committed(t)
	local model = createModel()
	local events = {}
	model:onChanged(function(event)
		events[#events + 1] = event.type
	end)

	model:setValues("format", {"osu"})
	model:commit()
	model:clearFilters()

	t:teq(events, {"filters_changed", "filters_changed"})
end

---@param t testing.T
function test.preserves_legacy_input_mode_selections(t)
	local model = createModel({
		["original input mode"] = {['7K'] = true, ['5K'] = false},
	})
	model:apply()

	t:tdeq(model:getInputModes("original input mode"), {"7K"})
	t:tdeq(model.combined_filters, {
		{"or", {inputmode__startswith = "7key"}},
	})
end

return test
