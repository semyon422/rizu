local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")

local lg = love.graphics

---Darkens the blurred background so text stays readable; stronger under the top and bottom bars.
---@class ui.screens.song_select_v2.Scrim : gui.View
---@operator call: ui.screens.song_select_v2.Scrim
---@field mesh love.Mesh?
local Scrim = View + {}

-- {position 0..1 from the top, opacity}
local STOPS = {{0, 0.84}, {0.22, 0.72}, {0.7, 0.72}, {1, 0.92}}

function Scrim:load()
	local r, g, b = Colors.background[1], Colors.background[2], Colors.background[3]
	local vertices = {} ---@type number[][]
	for _, stop in ipairs(STOPS) do
		vertices[#vertices + 1] = {0, stop[1], 0, 0, r, g, b, stop[2]}
		vertices[#vertices + 1] = {1, stop[1], 0, 0, r, g, b, stop[2]}
	end
	self.mesh = lg.newMesh(vertices, "strip", "static")
end

function Scrim:unload()
	if self.mesh then
		self.mesh:release()
		self.mesh = nil
	end
end

function Scrim:draw()
	Painter.setColorRgb(1, 1, 1, 1)
	lg.draw(assert(self.mesh), 0, 0, 0, self.width, self.height)
end

return Scrim
