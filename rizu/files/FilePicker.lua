local class = require("class")

---@alias rizu.files.FileDialogCallback fun(path: string?, error_message: string?)

---@class rizu.files.FilePicker
---@operator call: rizu.files.FilePicker
local FilePicker = class()

---@param show_file_dialog? fun(dialog_type: string, callback: function, settings: table)
function FilePicker:new(show_file_dialog)
	self.show_file_dialog = show_file_dialog or (love.window and love.window.showFileDialog)
end

---@param filters {[string]: string}?
---@return {[string]: string}
local function withAllFiles(filters)
	local result = {}
	for name, pattern in pairs(filters or {}) do
		result[name] = pattern
	end
	result["All files"] = "*"
	return result
end

---@param dialog_type "openfile"|"openfolder"|"savefile"
---@param settings table
---@param callback rizu.files.FileDialogCallback
function FilePicker:show(dialog_type, settings, callback)
	if not self.show_file_dialog then
		callback(nil, "This LÖVE build does not support native file dialogs.")
		return
	end
	local ok, err = pcall(self.show_file_dialog, dialog_type, function(files, _, dialog_err)
		if dialog_err then
			callback(nil, dialog_err)
		else
			callback(files and files[1] or nil, nil)
		end
	end, settings)
	if not ok then
		callback(nil, "Could not open the native file dialog: " .. tostring(err))
	end
end

---@param title string
---@param filters {[string]: string}?
---@param callback rizu.files.FileDialogCallback
function FilePicker:open(title, filters, callback)
	self:show("openfile", {
		title = title,
		filters = withAllFiles(filters),
		multiselect = false,
		attachtowindow = true,
	}, callback)
end

---@param title string
---@param callback rizu.files.FileDialogCallback
function FilePicker:openFolder(title, callback)
	self:show("openfolder", {
		title = title,
		multiselect = false,
		attachtowindow = true,
	}, callback)
end

---@param title string
---@param filename string?
---@param filters {[string]: string}?
---@param callback rizu.files.FileDialogCallback
function FilePicker:save(title, filename, filters, callback)
	self:show("savefile", {
		title = title,
		defaultname = filename,
		filters = filters or {},
		multiselect = false,
		attachtowindow = true,
	}, callback)
end

return FilePicker
