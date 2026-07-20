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

return test
