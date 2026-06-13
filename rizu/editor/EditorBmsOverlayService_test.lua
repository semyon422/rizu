local EditorBmsOverlayService = require("rizu.editor.EditorBmsOverlayService")

local test = {}

local function createContext(fields)
	return {
		getBmsToolsContext = function()
			return fields.bmsToolsContext
		end,
		applyBmsOffsetTempo = function()
			table.insert(fields.calls, "apply")
		end,
		changeBmsOffset = function(_, delta)
			table.insert(fields.calls, "offset:" .. delta)
		end,
		sliceKeysounds = function()
			table.insert(fields.calls, "slice")
		end,
		exportBmsTemplate = function(_, columnsOut)
			table.insert(fields.calls, "template:" .. columnsOut)
		end,
		exportUBmsC = function()
			table.insert(fields.calls, "ubmsc")
		end,
	}
end

---@param t testing.T
function test.state_methods_mutate_bms_tools_context(t)
	local bmsToolsContext = {
		offset = 0,
		tempo = 120,
		beat_offset = 0,
	}
	local service = EditorBmsOverlayService()
	local context = createContext({
		calls = {},
		bmsToolsContext = bmsToolsContext,
	})

	t:eq(service:getBmsToolsContext(context), bmsToolsContext)
	service:setOffsetTempo(context, 0.25, 150)
	service:setBeatOffset(context, 1.5)

	t:eq(bmsToolsContext.offset, 0.25)
	t:eq(bmsToolsContext.tempo, 150)
	t:eq(bmsToolsContext.beat_offset, 1.5)
end

---@param t testing.T
function test.command_methods_delegate_to_context(t)
	local calls = {}
	local service = EditorBmsOverlayService()
	local context = createContext({
		calls = calls,
		bmsToolsContext = {},
	})

	service:applyOffsetTempo(context)
	service:changeOffset(context, -0.001)
	service:sliceKeysounds(context)
	service:exportBmsTemplate(context, 7)
	service:exportUBmsC(context)

	t:tdeq(calls, {"apply", "offset:-0.001", "slice", "template:7", "ubmsc"})
end

return test
