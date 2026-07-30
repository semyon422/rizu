local AiChat = require("ui.modals.ai_chat.AiChat")
local Inputs = require("gui.input.Inputs")
local Screen = require("gui.Screen")
local Resources = require("ui.Resources")

local test = {}

---@param t testing.T
function test.wrapped_lines_are_cached_until_chat_or_width_changes(t)
	local old_get_font = Resources.getFont
	local old_love = love
	love = {
		math = old_love.math,
		graphics = {
			getDimensions = function()
				return 1920, 1080
			end,
		},
	}
	local wrap_calls = 0
	Resources.getFont = function()
		return {
			getWrap = function(_, text)
				wrap_calls = wrap_calls + 1
				return 0, {text}
			end,
		}
	end

	local observer
	local model = {
		entries = {{role = "tool", content = string.rep("result", 100), name = "lua_eval"}},
		onChanged = function(_, next_observer)
			observer = next_observer
		end,
	}
	local ok, err = xpcall(function()
		local view = AiChat(model --[[@as rizu.ai.ChatModel]], function() end)
		local first = view:getLines()
		local second = view:getLines()

		t:eq(first, second)
		t:eq(wrap_calls, 1)

		observer:receive({type = "chat_changed"})
		view:getLines()
		t:eq(wrap_calls, 2)

		view.width = view.width + 1
		view:getLines()
		t:eq(wrap_calls, 3)
	end, debug.traceback)
	Resources.getFont = old_get_font
	love = old_love
	if not ok then
		error(err)
	end
end

---@param t testing.T
function test.validates_transcript_text_before_wrapping(t)
	local old_get_font = Resources.getFont
	local old_love = love
	love = {math = old_love.math, graphics = {getDimensions = function() return 1920, 1080 end}}
	local wrapped_text
	Resources.getFont = function()
		return {
			getWrap = function(_, text)
				wrapped_text = text
				return 0, {text}
			end,
		}
	end

	local ok, err = xpcall(function()
		local model = {
			entries = {{
				role = "tool",
				content = "bad\255text",
				name = "read_file",
				tool_call_id = "call_1",
				arguments = "{}",
				status = "success",
			}},
			onChanged = function() end,
		}
		local view = AiChat(model --[[@as rizu.ai.ChatModel]], function() end)
		local lines = view:getLines()
		t:eq(lines[1].text, "[ok] read_file")
		t:eq(wrapped_text, "bad?text")
	end, debug.traceback)
	Resources.getFont = old_get_font
	love = old_love
	if not ok then
		error(err)
	end
end

---@param t testing.T
function test.centers_in_scaled_window_coordinates(t)
	local old_love = love
	love = {math = old_love.math, graphics = {getDimensions = function() return 1600, 900 end}}
	local ok, err = xpcall(function()
		local model = {
			entries = {},
			onChanged = function() end,
		}
		local view = AiChat(model --[[@as rizu.ai.ChatModel]], function() end)
		local screen = Screen()
		screen.root:add(view)
		screen:setUIScale(0.5)
		screen:resize(1600, 900)
		local center_x, center_y = view.world_transform:transformPoint(view.width / 2, view.height / 2)
		t:eq(center_x, 800)
		t:eq(center_y, 450)
	end, debug.traceback)
	love = old_love
	if not ok then error(err) end
end

---@param t testing.T
function test.model_selector_chooses_an_option(t)
	local old_love = love
	love = {math = old_love.math, graphics = {getDimensions = function() return 1600, 900 end}}
	local selected
	local options = {
		{provider_id = "local", provider_name = "Local", model = "qwen", label = "Local — qwen"},
		{provider_id = "openai", provider_name = "OpenAI", model = "gpt", label = "OpenAI — gpt"},
	}
	local ok, err = xpcall(function()
		local model = {
			busy = false,
			entries = {},
			onChanged = function() end,
			hasAuth = function() return false end,
			getModelOptions = function() return options end,
			selectModel = function(_, index) selected = index return true end,
		}
		local view = AiChat(model --[[@as rizu.ai.ChatModel]], function() end)
		local screen = Screen()
		screen.root:add(view)
		screen:resize(1600, 900)
		local button_x, button_y = view.world_transform:transformPoint(200, 20)
		view:onMouseClick({x = button_x, y = button_y} --[[@as gui.MouseClickEvent]])
		t:eq(view.model_menu_open, true)
		local row_x, row_y = view.world_transform:transformPoint(200, 48 + 30 + 15)
		view:onMouseClick({x = row_x, y = row_y} --[[@as gui.MouseClickEvent]])
		t:eq(selected, 2)
		t:eq(view.model_menu_open, false)
	end, debug.traceback)
	love = old_love
	if not ok then error(err) end
end

---@param t testing.T
function test.tool_results_are_collapsed_and_expandable(t)
	local old_get_font = Resources.getFont
	local old_love = love
	love = {math = old_love.math, graphics = {getDimensions = function() return 1920, 1080 end}}
	Resources.getFont = function()
		return {
			getWrap = function(_, text)
				return 0, {text}
			end,
		}
	end

	local ok, err = xpcall(function()
		local output = {}
		for index = 1, 12 do table.insert(output, "line " .. index) end
		local model = {
			entries = {{
				role = "tool",
				content = table.concat(output, "\n"),
				name = "read_file",
				tool_call_id = "call_1",
				arguments = [[{"line_end":12,"line_start":1}]],
				status = "success",
			}},
			onChanged = function() end,
		}
		local view = AiChat(model --[[@as rizu.ai.ChatModel]], function() end)
		local collapsed = view:getLines()
		t:eq(collapsed[2].text, "input")
		t:eq(collapsed[3].text, "line_end: 12\nline_start: 1")
		t:eq(collapsed[4].text, "output")
		t:eq(collapsed[5].text, "line 1\nline 2\nline 3\nline 4\nline 5")
		t:assert(collapsed[6].text:find("12 lines", 1, true))
		t:eq(#collapsed, 7)

		view:toggleTool("call_1")
		local expanded = view:getLines()
		t:eq(expanded[3].text, "line_end: 12\nline_start: 1")
		t:eq(expanded[5].text, table.concat(output, "\n"))
		t:eq(expanded[6].text, "Click to collapse")
	end, debug.traceback)
	Resources.getFont = old_get_font
	love = old_love
	if not ok then error(err) end
end

---@param t testing.T
function test.tool_preview_is_limited_by_rendered_lines(t)
	local old_get_font = Resources.getFont
	local old_love = love
	love = {math = old_love.math, graphics = {getDimensions = function() return 1920, 1080 end}}
	Resources.getFont = function()
		return {
			getWrap = function(_, text)
				if text == "long tool output" then
					return 0, {"row 1", "row 2", "row 3", "row 4", "row 5", "row 6", "row 7"}
				end
				return 0, {text}
			end,
		}
	end

	local ok, err = xpcall(function()
		local model = {
			entries = {{
				role = "tool",
				content = "long tool output",
				name = "inspect_runtime",
				tool_call_id = "call_1",
				arguments = "{}",
				status = "success",
			}},
			onChanged = function() end,
		}
		local view = AiChat(model --[[@as rizu.ai.ChatModel]], function() end)
		local collapsed = view:getLines()
		t:eq(collapsed[2].text, "output")
		t:eq(collapsed[3].text, "row 1")
		t:eq(collapsed[7].text, "row 5")
		t:assert(collapsed[8].text:find("click to expand", 1, true))
		t:eq(#collapsed, 9)

		view:toggleTool("call_1")
		local expanded = view:getLines()
		t:eq(expanded[3].text, "row 1")
		t:eq(expanded[9].text, "row 7")
		t:eq(expanded[10].text, "Click to collapse")
		t:eq(#expanded, 11)
	end, debug.traceback)
	Resources.getFont = old_get_font
	love = old_love
	if not ok then
		error(err)
	end
end

---@param t testing.T
function test.clicking_tool_footer_expands_result(t)
	local old_get_font = Resources.getFont
	local old_love = love
	love = {
		math = old_love.math,
		graphics = {getDimensions = function() return 1920, 1080 end},
		timer = old_love.timer,
	}
	Resources.getFont = function()
		return {
			getWrap = function(_, text)
				return 0, {text}
			end,
		}
	end

	local ok, err = xpcall(function()
		local output = {}
		for index = 1, 12 do table.insert(output, "line " .. index) end
		local model = {
			entries = {{
				role = "tool",
				content = table.concat(output, "\n"),
				name = "read_file",
				tool_call_id = "call_1",
				arguments = "{}",
				status = "success",
			}},
			onChanged = function() end,
		}
		local view = AiChat(model --[[@as rizu.ai.ChatModel]], function() end)
		view:setVisible(true)
		view:setOpacity(1)
		view:setScale(1, 1)
		local screen = Screen()
		screen.root:add(view)
		screen:resize(1920, 1080)

		local lines = view:getLines()
		local first, last = view:getVisibleRange(lines)
		local footer_index
		for index = first, last do
			if lines[index].text:find("click to expand", 1, true) then
				footer_index = index
				break
			end
		end
		t:assert(footer_index)
		local local_y = 48 + 18 + (footer_index - first) * 24 + 12
		local screen_x, screen_y = view.world_transform:transformPoint(100, local_y)
		local inputs = Inputs()
		inputs:beginFrame(screen_x, screen_y)
		screen:acceptInputs(inputs)
		local modifiers = {control = false, shift = false, alt = false, super = false}
		inputs:receive({name = "mousepressed", screen_x, screen_y, 1}, modifiers)
		inputs:receive({name = "mousereleased", screen_x, screen_y, 1}, modifiers)

		t:eq(view.expanded_tools.call_1, true)
		t:eq(view:getLines()[#view:getLines() - 1].text, "Click to collapse")
	end, debug.traceback)
	Resources.getFont = old_get_font
	love = old_love
	if not ok then
		error(err)
	end
end

---@param t testing.T
function test.detached_scroll_preserves_viewport_and_clamps(t)
	local old_get_font = Resources.getFont
	local old_love = love
	love = {math = old_love.math, graphics = {getDimensions = function() return 1920, 1080 end}}
	Resources.getFont = function()
		return {
			getWrap = function(_, text)
				return 0, {text}
			end,
		}
	end

	local ok, err = xpcall(function()
		local entries = {}
		for index = 1, 30 do
			table.insert(entries, {role = "assistant", content = "message " .. index})
		end
		local model = {
			entries = entries,
			onChanged = function() end,
		}
		local view = AiChat(model --[[@as rizu.ai.ChatModel]], function() end)
		local lines = view:getLines()
		view.scroll = 10
		local first = view:getVisibleRange(lines)
		local first_text = lines[first].text

		table.insert(entries, {role = "assistant", content = "new message"})
		view:receive({type = "chat_changed"})
		lines = view:getLines()
		first = view:getVisibleRange(lines)
		t:eq(lines[first].text, first_text)

		view.scroll = 100000
		view:clampScroll(lines)
		t:eq(view.scroll, view:getMaxScroll(lines))
		view.scroll = 0
		table.insert(entries, {role = "assistant", content = "latest"})
		view:receive({type = "chat_changed"})
		view:getLines()
		t:eq(view.scroll, 0)
	end, debug.traceback)
	Resources.getFont = old_get_font
	love = old_love
	if not ok then error(err) end
end

---@param t testing.T
function test.scrollbar_drag_moves_between_history_ends(t)
	local old_get_font = Resources.getFont
	local old_love = love
	love = {math = old_love.math, graphics = {getDimensions = function() return 1920, 1080 end}}
	Resources.getFont = function()
		return {
			getWrap = function(_, text)
				return 0, {text}
			end,
		}
	end

	local ok, err = xpcall(function()
		local entries = {}
		for index = 1, 40 do
			table.insert(entries, {role = "assistant", content = "message " .. index})
		end
		local model = {
			entries = entries,
			onChanged = function() end,
		}
		local view = AiChat(model --[[@as rizu.ai.ChatModel]], function() end)
		local screen = Screen()
		screen.root:add(view)
		screen:resize(1920, 1080)
		local lines = view:getLines()
		local scrollbar_x, track_y, track_height = view:getScrollbarMetrics(lines)
		local drag_x, drag_y = view.world_transform:transformPoint(scrollbar_x + 2, track_y + track_height - 2)
		t:assert(view:onDragStart({button = 1, x = drag_x, y = drag_y} --[[@as gui.DragStartEvent]]))
		t:eq(view.scroll, 0)

		drag_x, drag_y = view.world_transform:transformPoint(scrollbar_x + 2, track_y)
		t:assert(view:onDrag({button = 1, x = drag_x, y = drag_y} --[[@as gui.DragEvent]]))
		t:eq(view.scroll, view:getMaxScroll(lines))
		t:assert(view:onDragEnd({button = 1} --[[@as gui.DragEndEvent]]))
	end, debug.traceback)
	Resources.getFont = old_get_font
	love = old_love
	if not ok then
		error(err)
	end
end

return test
