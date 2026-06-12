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
		getMetadata = function()
			return {
				toChartmeta = function()
					table.insert(calls, "metadata")
					return chartmeta
				end,
			}
		end,
		setChartmeta = function(_, nextChartmeta)
			table.insert(calls, "chartmeta")
			savedChartmeta = nextChartmeta
		end,
		getNoteChartLoader = function()
			return {
				save = function()
					table.insert(calls, "notes")
				end,
			}
		end,
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
		getMetadata = function()
			return {
				toChartmeta = function()
					return chartmeta
				end,
			}
		end,
		setChartmeta = function(_, nextChartmeta)
			savedChartmeta = nextChartmeta
		end,
		getNoteChartLoader = function()
			return {
				save = function()
					error("save failed")
				end,
			}
		end,
	}

	t:has_error(function()
		EditorSaveService():save(context)
	end)

	t:eq(savedChartmeta, chartmeta)
end

return test
