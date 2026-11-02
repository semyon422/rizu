local class = require("class")
local Resources = require("ui.Resources")
local UiConfig = require("ui.UiConfig")

---@alias ui.screens.main_menu_v2.BackgroundLayers.Name "back"|"middle"|"front"

---The main menu background layers the player picked. A picked image is copied into the save directory,
---so moving or deleting the original does not lose it.
---@class ui.screens.main_menu_v2.BackgroundLayers
---@operator call: ui.screens.main_menu_v2.BackgroundLayers
---@field config ui.UiConfig
---@field private images {[string]: love.Image|false} By path in the save directory, false when it failed to load.
local BackgroundLayers = class()

---Back to front.
---@type ui.screens.main_menu_v2.BackgroundLayers.Name[]
BackgroundLayers.names = {"back", "middle", "front"}

BackgroundLayers.directory = "userdata/main_menu_background"

---The config value of a layer the player emptied.
BackgroundLayers.NONE = "none"

---@type {[ui.screens.main_menu_v2.BackgroundLayers.Name]: string}
local default_images = {back = "main_menu_bg", middle = "main_menu_bokeh", front = "main_menu_petals"}

---@param name ui.screens.main_menu_v2.BackgroundLayers.Name
---@param field "image"|"depth"|"fit"
---@return string key
function BackgroundLayers.key(name, field)
	return assert(UiConfig.keys["main_menu_" .. name .. "_" .. field], name)
end

---@param config ui.UiConfig
function BackgroundLayers:new(config)
	self.config = config
	self.images = {}
end

---@param name ui.screens.main_menu_v2.BackgroundLayers.Name
---@return string path A copied image, "" for the default art or NONE.
function BackgroundLayers:getPath(name)
	return self.config:getString(BackgroundLayers.key(name, "image"))
end

---@param name ui.screens.main_menu_v2.BackgroundLayers.Name
---@return love.Image? image The default art when the copied image is gone or does not load.
function BackgroundLayers:getImage(name)
	local path = self:getPath(name)
	if path == BackgroundLayers.NONE then
		return
	end
	local image ---@type love.Image|false|nil
	if path ~= "" then
		image = self.images[path]
		if image == nil then
			local ok, loaded = pcall(love.graphics.newImage, path)
			image = ok and loaded --[[@as love.Image]] or false
			self.images[path] = image
		end
	end
	return image or Resources.images[default_images[name]]
end

---@return ui.screens.main_menu.MainMenuBackground.Layer[]
function BackgroundLayers:getLayers()
	local config = self.config
	local layers = {} ---@type ui.screens.main_menu.MainMenuBackground.Layer[]
	for _, name in ipairs(BackgroundLayers.names) do
		local image = self:getImage(name)
		if image then
			layers[#layers + 1] = {
				image = image,
				depth = config:getNumber(BackgroundLayers.key(name, "depth")),
				fit = config:getChoice(BackgroundLayers.key(name, "fit")),
			}
		end
	end
	return layers
end

---@return number strength
function BackgroundLayers:getStrength()
	return self.config:getNumber(UiConfig.keys.main_menu_parallax)
end

---Copies an image file from anywhere on disk into the save directory and makes it the layer's image.
---@param name ui.screens.main_menu_v2.BackgroundLayers.Name
---@param source_path string
---@return boolean ok
---@return string? error
function BackgroundLayers:import(name, source_path)
	local opened, file, open_err = pcall(love.filesystem.openNativeFile, source_path, "r")
	if not opened or not file then
		return false, tostring(open_err or file)
	end
	local content = file:read()
	file:close()
	---@cast content string
	local file_name = source_path:match("[^/\\]+$") or "image"
	-- Decoded before it is stored, so a file that is not an image never replaces a working one.
	local ok, image = pcall(love.graphics.newImage, love.filesystem.newFileData(content, file_name))
	if not ok then
		return false, tostring(image)
	end

	local directory = BackgroundLayers.directory .. "/" .. name ---@type string
	self:deleteCopy(name)
	love.filesystem.createDirectory(directory)
	local path = directory .. "/" .. file_name ---@type string
	local written, err = love.filesystem.write(path, content)
	if not written then
		return false, err
	end
	self.images[path] = image --[[@as love.Image]]
	self.config:setString(BackgroundLayers.key(name, "image"), path)
	return true
end

---@private
---@param name ui.screens.main_menu_v2.BackgroundLayers.Name
function BackgroundLayers:deleteCopy(name)
	local path = self:getPath(name)
	-- ui.json is editable by hand: never delete a file this class did not copy.
	if path:sub(1, #BackgroundLayers.directory + 1) == BackgroundLayers.directory .. "/" then
		love.filesystem.remove(path)
	end
	self.images[path] = nil
end

---Shows the default art on the layer again, deleting a copied image.
---@param name ui.screens.main_menu_v2.BackgroundLayers.Name
function BackgroundLayers:reset(name)
	self:deleteCopy(name)
	self.config:setString(BackgroundLayers.key(name, "image"), "")
end

---Leaves the layer empty, deleting a copied image.
---@param name ui.screens.main_menu_v2.BackgroundLayers.Name
function BackgroundLayers:remove(name)
	self:deleteCopy(name)
	self.config:setString(BackgroundLayers.key(name, "image"), BackgroundLayers.NONE)
end

return BackgroundLayers
