local SliderMesh = {}

local max_render_points = 2048
local render_point_distance = 6

local vertex_format = {
	{"VertexPosition", "float", 2},
	{"SegmentStart", "float", 2},
	{"SegmentEnd", "float", 2},
	{"SegmentProgress", "float", 2},
}

---@param previous chart.osu.PathPoint
---@param point chart.osu.PathPoint
---@param next chart.osu.PathPoint
local function isSharpTurn(previous, point, next)
	local bx, by = point[1] - previous[1], point[2] - previous[2]
	local ax, ay = next[1] - point[1], next[2] - point[2]
	local denominator = math.sqrt(bx * bx + by * by) * math.sqrt(ax * ax + ay * ay)
	return denominator > 0 and (bx * ax + by * ay) / denominator < 0.95
end

---@param points chart.osu.PathPoint[]
---@return chart.osu.PathPoint[]
local function simplify(points)
	if #points <= 2 then return points end
	local output = {points[1]}
	for i = 2, #points - 1 do
		local previous, point, next = output[#output], points[i], points[i + 1]
		local dx, dy = point[1] - previous[1], point[2] - previous[2]
		if math.sqrt(dx * dx + dy * dy) >= render_point_distance or isSharpTurn(points[i - 1], point, next) then
			output[#output + 1] = point
		end
	end
	output[#output + 1] = points[#points]
	if #output <= max_render_points then return output end
	local limited = {}
	for i = 0, max_render_points - 1 do limited[i + 1] = output[math.floor(i * (#output - 1) / (max_render_points - 1)) + 1] end
	return limited
end

---@param path chart.osu.SliderPath
---@param radius number
---@return love.Mesh
function SliderMesh.create(path, radius)
	local points = simplify(path.points)
	---@type {[chart.osu.PathPoint]: number}
	local progress = {}
	if path.length > 0 then
		for i, point in ipairs(path.points) do progress[point] = path.distances[i] / path.length end
	end
	local vertices = {}
	local function add(x, y, start, finish)
		vertices[#vertices + 1] = {x, y, start[1], start[2], finish[1], finish[2], progress[start] or 0, progress[finish] or 1}
	end
	-- These are intentionally overlapping expanded segment quads. The slider
	-- shader evaluates each segment analytically and discards the quad area
	-- outside its capsule; drawing this mesh without that shader is invalid.
	for i = 2, #points do
		local start, finish = points[i - 1], points[i]
		local dx, dy = finish[1] - start[1], finish[2] - start[2]
		local length = math.sqrt(dx * dx + dy * dy)
		if length > 0 then
			local ax, ay = dx / length * radius, dy / length * radius
			local nx, ny = -dy / length * radius, dx / length * radius
			add(start[1] - ax + nx, start[2] - ay + ny, start, finish)
			add(start[1] - ax - nx, start[2] - ay - ny, start, finish)
			add(finish[1] + ax + nx, finish[2] + ay + ny, start, finish)
			add(finish[1] + ax + nx, finish[2] + ay + ny, start, finish)
			add(start[1] - ax - nx, start[2] - ay - ny, start, finish)
			add(finish[1] + ax - nx, finish[2] + ay - ny, start, finish)
		end
	end
	return love.graphics.newMesh(vertex_format, vertices, "triangles", "static")
end

return SliderMesh
