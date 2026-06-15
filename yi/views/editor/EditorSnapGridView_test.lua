local EditorSnapGridView = require("yi.views.editor.EditorSnapGridView")

local test = {}

local function withLove(mouseX, mouseY, leftDown, f)
	local oldLove = love
	love = {
		graphics = {
			getDimensions = function()
				return 800, 600
			end,
		},
		mouse = {
			getPosition = function()
				return mouseX, mouseY
			end,
			isDown = function(button)
				return button == 1 and leftDown or false
			end,
		},
	}
	local ok, err = xpcall(f, debug.traceback)
	love = oldLove
	if not ok then
		error(err)
	end
end

---@param t testing.T
function test.shift_drag_activation_uses_screen_to_snap_grid_transform(t)
	withLove(150, 400, true, function()
		local view = EditorSnapGridView({
			snap_grid_transform = {100, 50, 0, 1, 1, 0, 0, 0, 0},
			game = {
				noteSkinModel = {
					noteSkin = {
						baseOffset = 20,
						fullWidth = 40,
					},
				},
				editorModel = {
					isFineScrollRequested = function()
						return false
					end,
					isSnapChangeRequested = function()
						return true
					end,
				},
			},
		})

		t:eq(view:isMouseOverPlayfield(150, 400), true)
		t:eq(view:updateDragActive(), true)
		t:eq(view.dragActive, true)
	end)
end

---@param t testing.T
function test.shift_drag_activation_rejects_outside_columns(t)
	withLove(190, 400, true, function()
		local view = EditorSnapGridView({
			snap_grid_transform = {100, 50, 0, 1, 1, 0, 0, 0, 0},
			game = {
				noteSkinModel = {
					noteSkin = {
						baseOffset = 20,
						fullWidth = 40,
					},
				},
				editorModel = {
					isFineScrollRequested = function()
						return false
					end,
					isSnapChangeRequested = function()
						return true
					end,
				},
			},
		})

		t:eq(view:isMouseOverPlayfield(190, 400), false)
		t:eq(view:updateDragActive(), false)
		t:eq(view.dragActive, false)
	end)
end

return test
