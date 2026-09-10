local Objects = require("chart.format.osu.Objects")
-- Adapted from osu! lazer's full-chart stacking passes; see Stacking.LICENSE.
local RefChart = require("chart.refchart.RefChart")
local Restorer = require("chart.refchart.Restorer")

local Stacking = {}

---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return boolean
local function near(ax, ay, bx, by)
	return (ax - bx) ^ 2 + (ay - by) ^ 2 < 9
end

---@param chart chart.Chart
---@param sliders {[integer]: rizu.aim.Slider} Fresh runtime paths, translated in place.
---@param preempt number
---@param radius number
---@return chart.Chart
function Stacking.apply(chart, sliders, preempt, radius)
	local result = Restorer():restore(RefChart(chart))
	local objects = Objects.get(result, "osu")
	---@type number[], number[], number[], number[]
	local heights, ends, end_x, end_y = {}, {}, {}, {}
	local threshold = preempt * assert(chart.data.stack_leniency)
	for i, object in ipairs(objects) do
		heights[i] = 0
		ends[i], end_x[i], end_y[i] = object.time, object.x, object.y
		local slider = sliders[i]
		if slider then
			ends[i] = slider.timing.end_time
			end_x[i], end_y[i] = slider.path:position(slider.timing:progress(ends[i]))
		end
	end
	local work = 0
	local function spend()
		work = work + 1
		assert(work <= 2000000, "Aim prototype: stacking work budget exceeded.")
	end
	if chart.data.format_version > 5 then
		for i = #objects, 2, -1 do
			if heights[i] == 0 and objects[i].kind ~= "spinner" then
				local current = i
				for previous = i - 1, 1, -1 do
					spend()
					local p, c = objects[previous], objects[current]
					if p.kind ~= "spinner" then
						if objects[i].kind == "circle" then
							if c.time - ends[previous] > threshold then break end
							if sliders[previous] and near(end_x[previous], end_y[previous], c.x, c.y) then
								local offset = heights[current] - heights[previous] + 1
								for j = previous + 1, i do
									spend()
									if objects[j].kind ~= "spinner" and near(end_x[previous], end_y[previous], objects[j].x, objects[j].y) then
										heights[j] = heights[j] - offset
									end
								end
								break
							end
							if near(p.x, p.y, c.x, c.y) then
								heights[previous] = heights[current] + 1
								current = previous
							end
						else
							if c.time - p.time > threshold then break end
							if near(end_x[previous], end_y[previous], c.x, c.y) then
								heights[previous] = heights[current] + 1
								current = previous
							end
						end
					end
				end
			end
		end
	else
		for i, object in ipairs(objects) do
			if object.kind ~= "spinner" and (heights[i] == 0 or sliders[i]) then
				local end_time, tail_stack = ends[i], 0
				local x, y = object.x, object.y
				if sliders[i] then x, y = sliders[i].path:position(1) end
				for j = i + 1, #objects do
					spend()
					local other = objects[j]
					if other.time - end_time > threshold then break end
					if other.kind ~= "spinner" then
						if near(object.x, object.y, other.x, other.y) then
							heights[i] = heights[i] + 1
							end_time = other.time
						elseif near(x, y, other.x, other.y) then
							tail_stack = tail_stack + 1
							heights[j] = heights[j] - tail_stack
							end_time = other.time
						end
					end
				end
			end
		end
	end
	for i, object in ipairs(objects) do
		local offset = -heights[i] * radius / 10
		object.stack_height = heights[i]
		object.x, object.y = object.x + offset, object.y + offset
		local slider = sliders[i]
		if slider then
			for _, point in ipairs(slider.path.points) do
				point[1], point[2] = point[1] + offset, point[2] + offset
			end
			for _, point in ipairs(assert(object.slider).controls) do
				point[1], point[2] = point[1] + offset, point[2] + offset
			end
		end
	end
	return result
end

return Stacking
