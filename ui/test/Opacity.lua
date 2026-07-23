local coloredRect = require("ui.test.ColoredRect")

---@type {elapsed: number, fading_view: gui.View?}
local state = {elapsed = 0, fading_view = nil}

---@param parent gui.View
---@param x number
---@param y number
---@param opacity number
local function addSample(parent, x, y, opacity)
	local backdrop = coloredRect(0.22, 0.22, 0.25)
	backdrop.offset_min = {x, y}
	backdrop.offset_max = {x + 120, y + 140}
	parent:add(backdrop)

	local sample = coloredRect(0.25, 0.65, 0.95)
	sample.anchor_max = {1, 1}
	sample.offset_min = {10, 10}
	sample.offset_max = {-10, -10}
	sample:setOpacity(opacity)
	backdrop:add(sample)
end

---@type ui.test.TestCase
local case = {
	name = "opacity",
	build = function(root)
		state.elapsed = 0
		state.fading_view = nil

		local bg = coloredRect(0.08, 0.08, 0.1)
		bg.anchor_max = {1, 1}
		root:add(bg)

		local opacities = {1, 0.75, 0.5, 0.25, 0}
		for i, opacity in ipairs(opacities) do
			addSample(root, 80 + (i - 1) * 150, 100, opacity)
		end

		local inherited = coloredRect(0.95, 0.55, 0.2)
		inherited.offset_min = {230, 300}
		inherited.offset_max = {530, 500}
		inherited:setOpacity(0.5)
		root:add(inherited)

		local child = coloredRect(0.25, 0.55, 0.95)
		child.anchor_max = {1, 1}
		child.offset_min = {50, 50}
		child.offset_max = {-50, -50}
		child:setOpacity(0.5)
		inherited:add(child)

		local fading_view = coloredRect(0.85, 0.3, 0.65)
		fading_view.offset_min = {580, 300}
		fading_view.offset_max = {780, 500}
		root:add(fading_view)
		state.fading_view = fading_view
	end,
	update = function(screen, dt)
		local fading_view = state.fading_view
		if not fading_view or fading_view.parent ~= screen.root then
			return
		end
		state.elapsed = state.elapsed + dt
		fading_view:setOpacity((math.sin(state.elapsed * 2) + 1) / 2)
	end,
}

return case
