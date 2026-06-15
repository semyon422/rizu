local EditorControlRenderer = require("yi.views.editor.EditorControlRenderer")

local test = {}

local function withLove(f)
	local oldLove = love
	local calls = {}
	love = {
		graphics = {
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
function test.button_draws_active_background_and_centered_label(t)
	withLove(function(calls)
		EditorControlRenderer():button("play", 1, 2, 100, 20, true, false)

		t:tdeq(calls[1], {"color", 0.5, 0.65, 1, 0.9})
		t:tdeq(calls[2], {"rectangle", "fill", 1, 2, 100, 20, 4, 4})
		t:tdeq(calls[3], {"color", 1, 1, 1, 1})
		t:tdeq(calls[4], {"printf", "play", 1, 7, 100, "center"})
	end)
end

---@param t testing.T
function test.slider_clamps_fill_width(t)
	withLove(function(calls)
		EditorControlRenderer():slider("rate", 0, 0, 100, 20, false, true, 2)

		t:tdeq(calls[1], {"color", 0.35, 0.42, 0.55, 0.95})
		t:tdeq(calls[2], {"rectangle", "fill", 0, 0, 100, 20, 4, 4})
		t:tdeq(calls[3], {"color", 0.7, 0.78, 1, 0.9})
		t:tdeq(calls[4], {"rectangle", "fill", 0, 0, 100, 20, 4, 4})
	end)
end

return test
