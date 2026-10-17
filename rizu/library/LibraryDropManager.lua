local class = require("class")
local thread = require("thread")
local path_util = require("path_util")
local fs_util = require("fs_util")
local Sph = require("chart.format.sph.Sph")

---@class rizu.library.LibraryDropManager
---@operator call: rizu.library.LibraryDropManager
local LibraryDropManager = class()

---@param library rizu.library.Library
---@param skin_registry rizu.skin.SkinRegistry
function LibraryDropManager:new(library, skin_registry)
	self.library = library
	self.skin_registry = skin_registry
end

---@param event table
function LibraryDropManager:receive(event)
	if event.name == "filedropped" then
		self:filedropped(event[1])
	elseif event.name == "directorydropped" then
		self:directorydropped(event[1])
	end
end

---@param path string
function LibraryDropManager:directorydropped(path)
	-- self.library.locations:updateLocationPath(path)
end

---@alias rizu.library.FileDroppedHandler fun(self: rizu.library.LibraryDropManager, path: string, data: string)

---@type {[string]: rizu.library.FileDroppedHandler}
local filedropped_handlers = {}

---@param self rizu.library.LibraryDropManager
---@param path string
---@param data string
function filedropped_handlers.new_chart(self, path, data)
	local _name, ext = path_util.name_ext(path)
	assert(ext)
	local audioName = _name:match("^.+/(.-)$") or _name
	local location_path = path_util.join("editor", os.time() .. " " .. audioName)
	local chartSetPath = path_util.join("userdata/charts", location_path)

	love.filesystem.createDirectory(chartSetPath)
	assert(love.filesystem.write(chartSetPath .. "/" .. audioName .. "." .. ext, data))
	assert(love.filesystem.write(chartSetPath .. "/" .. audioName .. ".sph", Sph:getDefault({
		audio = audioName .. "." .. ext
	})))

	self.library:computeLocation(location_path, 1)
end

---@param self rizu.library.LibraryDropManager
---@param path string
---@param data string
function filedropped_handlers.add_zip(self, path, data)
	local location_path = path_util.join("dropped", path:match("^.+/(.-)%.osz$"))
	local extractPath = path_util.join("userdata/charts", location_path)

	print(("Extracting to: %s"):format(extractPath))
	print(path, extractPath)
	local extracted = fs_util.extractAsync(path, extractPath)
	if not extracted then
		print("Failed to extract")
		return
	end
	print("Extracted")

	self.library:computeLocation(location_path, 1)
end
filedropped_handlers.add_zip = thread.coro(filedropped_handlers.add_zip)

---@param self rizu.library.LibraryDropManager
---@param path string
---@param data string
function filedropped_handlers.add_osu_skin(self, path, data)
	local name = path_util.fix_illegal(path:match("([^/]+)%.[^./]+$") or "skin")
	local extract_path = path_util.join("userdata/dlc/skins_osu", name)

	local extracted, err = fs_util.extractAsync(path, extract_path)
	if not extracted then
		print(("Failed to extract osu! skin %s: %s"):format(path, err))
		return
	end

	self.skin_registry:load()
end
filedropped_handlers.add_osu_skin = thread.coro(filedropped_handlers.add_osu_skin)

local exts = {
	osk = filedropped_handlers.add_osu_skin,
	mp3 = filedropped_handlers.new_chart,
	ogg = filedropped_handlers.new_chart,
	osz = filedropped_handlers.add_zip,
}

---@param file love.File
function LibraryDropManager:filedropped(file)
	local path = file:getFilename():gsub("\\", "/")

	local ext = path:match("^.+%.(.-)$")
	ext = ext and ext:lower()
	local handler = exts[ext]
	if not handler then
		return
	end

	file:open("r")
	local data = file:read()
	handler(self, path, data)
end

return LibraryDropManager
