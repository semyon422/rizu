local SongSelect = require("ui.screens.song_select.SongSelect")

local test = {}

---@param t testing.T
function test.enter_reannounces_selection_on_each_return(t)
	local notifications = 0
	local function noop() end
	local selector = {
		onChanged = noop,
		notifyChartviewChanged = function()
			notifications = notifications + 1
		end,
	}
	local screen = {
		ui = {
			game = {
				chartSelector = selector,
				scoreSelector = {onChanged = noop},
				collectionSelector = {onChanged = noop},
			},
			command_registry = {pushContext = noop},
		},
		score_list_panel = {score_list = {reload = noop}},
		library_toolbar = {updateCollections = noop},
		footer = {updateState = noop},
		root = {fadeIn = noop, scaleTo = noop},
	}

	SongSelect.enter(screen)
	t:eq(notifications, 1)
	SongSelect.enter(screen)
	t:eq(notifications, 2)
end

return test
