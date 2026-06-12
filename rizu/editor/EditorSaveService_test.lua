local EditorSaveService = require("rizu.editor.EditorSaveService")

local test = {}

---@param t testing.T
function test.save_updates_chartmeta_before_saving_chart_data(t)
	local calls = {}
	local chartmeta = {
		title = "Title",
	}
	local savedChartmeta
	local context = {
		metadata = {
			toChartmeta = function()
				table.insert(calls, "metadata")
				return chartmeta
			end,
		},
		setChartmeta = function(nextChartmeta)
			table.insert(calls, "chartmeta")
			savedChartmeta = nextChartmeta
		end,
		noteChartLoader = {
			save = function()
				table.insert(calls, "notes")
			end,
		},
	}

	EditorSaveService():save(context)

	t:eq(savedChartmeta, chartmeta)
	t:tdeq(calls, {"metadata", "chartmeta", "notes"})
end

---@param t testing.T
function test.chartmeta_is_updated_when_note_save_fails(t)
	local chartmeta = {
		title = "Title",
	}
	local savedChartmeta
	local context = {
		metadata = {
			toChartmeta = function()
				return chartmeta
			end,
		},
		setChartmeta = function(nextChartmeta)
			savedChartmeta = nextChartmeta
		end,
		noteChartLoader = {
			save = function()
				error("save failed")
			end,
		},
	}

	t:has_error(function()
		EditorSaveService():save(context)
	end)

	t:eq(savedChartmeta, chartmeta)
end

return test
