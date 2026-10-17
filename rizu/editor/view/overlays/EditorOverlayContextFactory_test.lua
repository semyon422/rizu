local EditorOverlayContextFactory = require("rizu.editor.view.overlays.EditorOverlayContextFactory")

local test = {}

---@param t testing.T
function test.create_info_overlay_context_adapts_metadata_and_save_commands(t)
	local calls = {}
	local metadata = {
		iter = function()
			table.insert(calls, "iter")
			return function() end
		end,
		set = function(_, key, value)
			table.insert(calls, "metadata:" .. key .. "=" .. value)
		end,
	}
	local screen = {
		game = {
			editorModel = {
				metadata = metadata,
			},
			editorController = {
				save = function()
					table.insert(calls, "save")
				end,
				saveToOsu = function()
					table.insert(calls, "osu")
				end,
				saveToNanoChart = function()
					table.insert(calls, "nano")
				end,
			},
		},
	}

	local context = EditorOverlayContextFactory():createInfoOverlayContext(screen, {})

	context:iterMetadata()
	context:setMetadata("title", "Song")
	context:save()
	context:saveToOsu()
	context:saveToNanoChart()

	t:tdeq(calls, {"iter", "metadata:title=Song", "save", "osu", "nano"})
end

---@param t testing.T
function test.create_bms_overlay_context_adapts_overlay_actions_and_exports(t)
	local calls = {}
	local bmsToolsContext = {}
	local overlayContext = {
		getBmsToolsContext = function()
			return bmsToolsContext
		end,
	}
	local screen = {
		editorViewServices = {
			overlayActionService = {
				applyBmsOffsetTempo = function(_, context)
					t:eq(context, overlayContext)
					table.insert(calls, "apply")
				end,
				changeBmsOffset = function(_, context, delta)
					t:eq(context, overlayContext)
					table.insert(calls, "offset:" .. delta)
				end,
			},
		},
		game = {
			editorController = {
				sliceKeysounds = function()
					table.insert(calls, "slice")
				end,
				exportBmsTemplate = function(_, columnsOut)
					table.insert(calls, "template:" .. columnsOut)
				end,
				exportUBmsC = function()
					table.insert(calls, "ubmsc")
				end,
			},
		},
	}

	local context = EditorOverlayContextFactory():createBmsOverlayContext(screen, overlayContext)

	t:eq(context:getBmsToolsContext(), bmsToolsContext)
	context:applyBmsOffsetTempo()
	context:changeBmsOffset(0.1)
	context:sliceKeysounds()
	context:exportBmsTemplate(7)
	context:exportUBmsC()

	t:tdeq(calls, {"apply", "offset:0.1", "slice", "template:7", "ubmsc"})
end

return test
