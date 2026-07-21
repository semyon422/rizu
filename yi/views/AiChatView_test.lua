local AiChatView = require("yi.views.AiChatView")
local Resources = require("yi.Resources")

local test = {}

---@param t testing.T
function test.wrapped_lines_are_cached_until_chat_or_width_changes(t)
	local old_get_font = Resources.getFont
	local old_love = love
	love = {
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
		local view = AiChatView(model --[[@as rizu.ai.ChatModel]], function() end)
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
	love = {graphics = {getDimensions = function() return 1920, 1080 end}}
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
			entries = {{role = "tool", content = "bad\255text", name = "read_file"}},
			onChanged = function() end,
		}
		local view = AiChatView(model --[[@as rizu.ai.ChatModel]], function() end)
		view:getLines()
		t:eq(wrapped_text, "[tool read_file] bad?text")
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
	love = {graphics = {getDimensions = function() return 1600, 900 end}}
	local ok, err = xpcall(function()
		local model = {
			entries = {},
			onChanged = function() end,
		}
		local view = AiChatView(model --[[@as rizu.ai.ChatModel]], function() end)
		view.ui_scale = 0.5
		view:load()
		view:applyLayout()
		local center_x, center_y = view.transform:transformPoint(view.width / 2, view.height / 2)
		t:eq(center_x, 800)
		t:eq(center_y, 450)
	end, debug.traceback)
	love = old_love
	if not ok then error(err) end
end

---@param t testing.T
function test.model_selector_chooses_an_option(t)
	local old_love = love
	love = {graphics = {getDimensions = function() return 1600, 900 end}}
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
		local view = AiChatView(model --[[@as rizu.ai.ChatModel]], function() end)
		view:load()
		view:applyLayout()
		local button_x, button_y = view.transform:transformPoint(200, 20)
		view:onMouseClick({x = button_x, y = button_y} --[[@as gui.MouseClickEvent]])
		t:eq(view.model_menu_open, true)
		local row_x, row_y = view.transform:transformPoint(200, 48 + 30 + 15)
		view:onMouseClick({x = row_x, y = row_y} --[[@as gui.MouseClickEvent]])
		t:eq(selected, 2)
		t:eq(view.model_menu_open, false)
	end, debug.traceback)
	love = old_love
	if not ok then error(err) end
end

return test
