local Editor = require("yi.layers.Editor")

local test = {}

---@param t testing.T
function test.enter_and_exit_do_not_require_chart_menus(t)
	local old_love = love
	love = {
		graphics = {
			getDimensions = function()
				return 1920, 1080
			end,
		},
	}

	local ok, err = xpcall(function()
		local calls = {}
		local yi = {
			game = {},
			setScreen = function(_, screen_name)
				table.insert(calls, "screen:" .. screen_name)
			end,
		}
		local editor = Editor(yi)

		editor.editorScreenLoadService = {
			enter = function(_, screen)
				table.insert(calls, "enter")
				screen.editor_loaded = true
			end,
			exit = function(_, screen)
				table.insert(calls, "exit")
				screen.editor_loaded = false
			end,
		}

		editor:enter()
		editor:exit()
		t:eq(editor:handleKeyDown("escape"), true)

		t:tdeq(calls, {
			"enter",
			"exit",
			"screen:select",
		})
	end, debug.traceback)

	love = old_love
	if not ok then
		error(err)
	end
end

return test
