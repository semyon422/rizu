local FakeFilesystem = require("fs.FakeFilesystem")
local Fraction = require("chart.core.Fraction")

local test = {}

---@param t testing.T
---@param inputmode string
---@param column string
---@param expected_column integer
local function check_column(t, inputmode, column, expected_column)
	local fs = FakeFilesystem()
	fs:createDirectory("charts")
	fs:write("charts/iBMSC Clipboard Data xNT.txt", "iBMSC Clipboard Data xNT\n6 0 1 0 0")

	local loader = assert(loadfile("rizu/editor/exports/UbmscExporter.lua"))
	setfenv(loader, setmetatable({love = {filesystem = {
		read = function(path) return fs:read(path) end,
		write = function(path, data) return fs:write(path, data) end,
	}}}, {__index = _G}))
	local UbmscExporter = loader()
	UbmscExporter():export({chartview = {real_dir = "charts", inputmode = inputmode}}, {
		notes = {getLinkedNotes = function()
			return {{
				getColumn = function() return column end,
				startNote = {visualPoint = {point = {
					getGlobalTime = function() return Fraction(4) end,
				}}},
			}}
		end},
	})
	t:eq(fs:read("charts/iBMSC Clipboard Data xNT out.txt"),
		"iBMSC Clipboard Data xNT\r\n" .. expected_column .. " 0 1 0 0")
end

---@param t testing.T
function test.exports_seven_keys_and_scratch(t)
	for i = 1, 7 do
		check_column(t, "7key1scratch", "key" .. i, 5 + i)
	end
	check_column(t, "7key1scratch", "scratch1", 5)
end

---@param t testing.T
function test.retains_ten_key_mapping(t)
	check_column(t, "10key", "key10", 18)
end

return test
