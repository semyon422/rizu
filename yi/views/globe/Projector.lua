---@class yi.globe.Projector
local Projector = {}

local sin = math.sin
local cos = math.cos
local pi = math.pi

---@param x number
---@param y number
---@param z number
---@param rotation_x number
---@param rotation_y number
---@return number
---@return number
---@return number
function Projector.rotatePoint(x, y, z, rotation_x, rotation_y)
	local cos_y = cos(rotation_y)
	local sin_y = sin(rotation_y)
	local rotated_x = x * cos_y - z * sin_y
	local rotated_z = x * sin_y + z * cos_y

	local cos_x = cos(rotation_x)
	local sin_x = sin(rotation_x)
	local final_y = y * cos_x - rotated_z * sin_x
	local final_z = y * sin_x + rotated_z * cos_x

	return rotated_x, final_y, final_z
end

---@param x number
---@param y number
---@param z number
---@param center_x number
---@param center_y number
---@param perspective number
---@param camera_z number
---@return number?
---@return number?
---@return number?
function Projector.projectPoint(x, y, z, center_x, center_y, perspective, camera_z)
	local depth = z + camera_z
	if depth <= 0.001 then
		return nil, nil, nil
	end

	local scale = perspective / depth
	return center_x + x * scale, center_y + y * scale, scale
end

---@param radius number
---@param latitudes integer
---@param longitudes integer
---@return table[]
function Projector.buildWireframe(radius, latitudes, longitudes)
	local segments = {}
	latitudes = math.max(2, latitudes)
	longitudes = math.max(3, longitudes)

	for latitude_index = 1, latitudes - 1 do
		local latitude = -pi / 2 + pi * latitude_index / latitudes
		local ring_radius = radius * cos(latitude)
		local ring_y = radius * sin(latitude)

		for longitude_index = 0, longitudes - 1 do
			local angle_1 = 2 * pi * longitude_index / longitudes
			local angle_2 = 2 * pi * (longitude_index + 1) / longitudes

			segments[#segments + 1] = {
				ring_radius * cos(angle_1),
				ring_y,
				ring_radius * sin(angle_1),
				ring_radius * cos(angle_2),
				ring_y,
				ring_radius * sin(angle_2),
			}
		end
	end

	for longitude_index = 0, longitudes - 1 do
		local longitude = 2 * pi * longitude_index / longitudes
		local cos_longitude = cos(longitude)
		local sin_longitude = sin(longitude)

		for latitude_index = 0, latitudes - 1 do
			local latitude_1 = -pi / 2 + pi * latitude_index / latitudes
			local latitude_2 = -pi / 2 + pi * (latitude_index + 1) / latitudes

			segments[#segments + 1] = {
				radius * cos(latitude_1) * cos_longitude,
				radius * sin(latitude_1),
				radius * cos(latitude_1) * sin_longitude,
				radius * cos(latitude_2) * cos_longitude,
				radius * sin(latitude_2),
				radius * cos(latitude_2) * sin_longitude,
			}
		end
	end

	return segments
end

return Projector
