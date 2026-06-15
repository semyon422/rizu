local EditorWidgets = require("yi.views.editor.EditorWidgets")

local test = {}

local function withLove(f)
	local oldLove = love
	local calls = {}
	love = {
		graphics = {
			transformPoint = function(x, y)
				return x, y
			end,
			setColor = function(...)
				table.insert(calls, {"color", ...})
			end,
			rectangle = function(...)
				table.insert(calls, {"rectangle", ...})
			end,
			line = function(...)
				table.insert(calls, {"line", ...})
			end,
			printf = function(...)
				table.insert(calls, {"printf", ...})
			end,
			getFont = function()
				return {
					getHeight = function()
						return 10
					end,
				}
			end,
		},
		mouse = {
			getPosition = function()
				return 10, 10
			end,
		},
	}
	local ok, err = xpcall(function()
		f(calls)
	end, debug.traceback)
	love = oldLove
	if not ok then
		error(err)
	end
end

---@param t testing.T
function test.button_registers_draws_and_reports_click(t)
	withLove(function()
		local widgets = EditorWidgets()
		t:eq(widgets:button("save", "save", 0, 0, 100, 20), false)

		widgets:onMouseDown({x = 10, y = 10})
		widgets:onMouseUp({x = 10, y = 10})

		t:eq(widgets:button("save", "save", 0, 0, 100, 20), true)
	end)
end

---@param t testing.T
function test.slider_maps_drag_fraction_and_snaps(t)
	withLove(function()
		local widgets = EditorWidgets()
		widgets:slider("rate", 0.5, 0.5, 2, 0.01, "0.50x", 0, 0, 100, 20)
		widgets:onMouseDown({x = 25, y = 10})

		t:eq(widgets:slider("rate", 0.5, 0.5, 2, 0.01, "0.88x", 0, 0, 100, 20), 0.88)
	end)
end

---@param t testing.T
function test.input_keeps_edit_value_while_focused(t)
	withLove(function()
		local widgets = EditorWidgets()
		t:eq(widgets:input("title", "Song", "title", 0, 0, 100, 20), "Song")

		widgets:onMouseDown({x = 10, y = 10})
		widgets:onTextInput({key = "!"})

		t:eq(widgets:input("title", "Song", "title", 0, 0, 100, 20), "Song!")
	end)
end

return test
