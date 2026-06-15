local EditorWaveformView = require("yi.views.editor.EditorWaveformView")

local test = {}

local function withLove(f)
	local oldLove = love
	local calls = {}
	love = {
		graphics = {
			getDimensions = function()
				return 800, 600
			end,
			push = function(...)
				table.insert(calls, {"push", ...})
			end,
			pop = function(...)
				table.insert(calls, {"pop", ...})
			end,
			setLineJoin = function(...)
				table.insert(calls, {"lineJoin", ...})
			end,
			setLineStyle = function(...)
				table.insert(calls, {"lineStyle", ...})
			end,
			setLineWidth = function(...)
				table.insert(calls, {"lineWidth", ...})
			end,
			setColor = function(...)
				table.insert(calls, {"color", ...})
			end,
			replaceTransform = function(...)
				table.insert(calls, {"replaceTransform", ...})
			end,
			translate = function(...)
				table.insert(calls, {"translate", ...})
			end,
			scale = function(...)
				table.insert(calls, {"scale", ...})
			end,
			line = function(...)
				table.insert(calls, {"line", ...})
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
function test.draw_requests_waveform_for_visible_view_height(t)
	withLove(function()
		local capturedHeight
		local noteSkin = {
			baseOffset = 20,
			fullWidth = 40,
			hitposition = 300,
		}
		local editor = {
			waveform = {
				opacity = 0.5,
				scale = 0.25,
			},
		}
		local view = EditorWaveformView({
			transform = {100, 50, 0, 1, 1, 0, 0, 0, 0},
			editorViewServices = {
				waveformService = {
					update = function(_, _context, nextNoteSkin, nextEditor, height)
						t:eq(nextNoteSkin, noteSkin)
						t:eq(nextEditor, editor)
						capturedHeight = height
						return {
							lines = {
								[0] = {1, 2, 3, 4},
							},
							pointDrawDelta = 0.25,
							channelCount = 1,
						}
					end,
				},
			},
			game = {
				noteSkinModel = {
					noteSkin = noteSkin,
				},
				configModel = {
					configs = {
						settings = {
							editor = editor,
						},
					},
				},
				editorModel = {
					context = {
						getViewContext = function()
							return {}
						end,
					},
				},
			},
		})

		view:setHeight(480)
		view:draw()

		t:eq(capturedHeight, 480)
	end)
end

return test
