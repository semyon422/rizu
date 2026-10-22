local JudgeSprites = {}

local DIR = "resources/rizu_base_skin/judges/"

-- Fallback sprites and colors by judge index; 1 is the best hit.
local fallbacks = {"marvelous", "perfect", "great", "good", "bad", "miss"}
local colors = {
	{0, 1, 1, 1}, -- cyan
	{1, 1, 0, 1}, -- yellow
	{0, 1, 0, 1}, -- green
	{0.2, 0.4, 1, 1}, -- blue
	{1, 0, 1, 1}, -- magenta
	{1, 0, 0, 1}, -- red
}
local MISS = #fallbacks

---Loaded images by sprite name; tests pre-fill it instead of touching the filesystem.
---@type {[string]: love.Image|false}
local images = {}
JudgeSprites.images = images

---@param name string
---@return love.Image?
local function load_image(name)
	local image = images[name]
	if image == nil then
		local path = DIR .. name .. ".png"
		image = love.filesystem.getInfo(path) and love.graphics.newImage(path) or false
		images[name] = image
	end
	return image or nil
end

---Picks the sprite and tint of a judge. The last judge is always the miss.
---@param names string[]
---@param index integer 1 is the best hit
---@return love.Image
---@return number[] color
function JudgeSprites.get(names, index)
	local slot = index >= #names and MISS or math.min(index, MISS)
	local image = load_image(names[index] or "") or load_image(fallbacks[slot])
	return assert(image), colors[slot]
end

return JudgeSprites
