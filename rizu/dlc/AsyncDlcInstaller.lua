local class = require("class")
local thread = require("thread")

---@alias rizu.dlc.AsyncInstallFunc fun(id: string|number, _type: rizu.dlc.DlcType, data: string, filename: string, metadata: table?): boolean?, string?

local install_async = thread.async(function(id, _type, data, filename, metadata)
	local DlcInstaller = require("rizu.dlc.DlcInstaller")
	return DlcInstaller():install(id, _type, data, filename, metadata)
end)

---@class rizu.dlc.AsyncDlcInstaller
---@operator call: rizu.dlc.AsyncDlcInstaller
---@field install_func rizu.dlc.AsyncInstallFunc
local AsyncDlcInstaller = class()

---@param install_func rizu.dlc.AsyncInstallFunc?
function AsyncDlcInstaller:new(install_func)
	self.install_func = install_func or install_async
end

---@param id string|number
---@param _type rizu.dlc.DlcType
---@param data string
---@param filename string
---@param metadata table?
---@return boolean? success
---@return string? error
function AsyncDlcInstaller:install(id, _type, data, filename, metadata)
	return self.install_func(id, _type, data, filename, metadata)
end

return AsyncDlcInstaller
