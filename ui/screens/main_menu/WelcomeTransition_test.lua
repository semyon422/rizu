local WelcomeTransition = require("ui.screens.main_menu.WelcomeTransition")
local Resources = require("ui.Resources")
local Screen = require("gui.Screen")

local test = {}

---@param t number
---@param cols integer
---@param ox number
---@param oy number
---@param check fun(scale: number): boolean
---@return boolean
local function everyTile(t, cols, ox, oy, check)
	for r = 0, 8 do
		for c = 0, cols - 1 do
			if not check((WelcomeTransition.tile(t, r, c, cols, ox, oy))) then return false end
		end
	end
	return true
end

---@param t testing.T
function test.tiles_cover_the_screen_when_it_switches_and_are_gone_at_the_end(t)
	for _, cols in ipairs({12, 16, 22}) do
		for _, origin in ipairs({{cols / 2, 4}, {0, 0}, {cols - 1, 8}}) do
			local ox, oy = origin[1], origin[2]
			t:assert(everyTile(0, cols, ox, oy, function(scale) return scale < 1 end), "tiles start open")
			t:assert(everyTile(WelcomeTransition.COVERED, cols, ox, oy, function(scale) return scale >= 1 end), "covered")
			t:assert(everyTile(WelcomeTransition.DURATION, cols, ox, oy, function(scale) return scale == 0 end), "cleared")
		end
	end
end

---@param t testing.T
function test.switches_once_and_removes_itself(t)
	if not love.graphics.isActive() then assert(love.window.setMode(1600, 900)) end
	Resources.load()
	local covered = 0
	local transition = WelcomeTransition(function() covered = covered + 1 end, "WELCOME", 800, 450)
	local screen = Screen()
	screen.root:add(transition)
	transition:anchorFill(0, 0, 0, 0)
	screen:load()
	screen:resize(1600, 900)

	for _ = 1, math.ceil(WelcomeTransition.DURATION * 10) + 1 do
		screen:update(0.1)
		love.graphics.clear()
		screen:draw()
		love.graphics.present()
	end
	screen:flush()

	t:eq(covered, 1)
	t:eq(transition.parent, nil)
end

return test
