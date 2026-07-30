local AiChat = require("ui.modals.ai_chat.AiChat")
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
		t:eq(lines[1].text, "[ok] read_file  {}")
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
		t:eq(collapsed[2].text, "line 1\nline 2\nline 3\nline 4\nline 5")
		t:assert(collapsed[3].text:find("12 lines", 1, true))
		t:eq(#collapsed, 4)

		view:toggleTool("call_1")
		local expanded = view:getLines()
		t:eq(expanded[2].text, table.concat(output, "\n"))
		t:eq(expanded[3].text, "Click to collapse")
	end, debug.traceback)
	Resources.getFont = old_get_font
	love = old_love
	if not ok then error(err) end
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

return test
