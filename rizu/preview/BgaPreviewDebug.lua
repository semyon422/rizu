local BgaPreviewDebug = {}

BgaPreviewDebug.path = "tmp/bga-preview-debug.log"

---@param ... any
function BgaPreviewDebug.warn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end

	local prefix = ""
	if love and love.timer and love.timer.getTime then
		prefix = ("%.3f "):format(love.timer.getTime())
	end
	local line = prefix .. table.concat(parts, "\t")
	print(line)
	if love and love.filesystem and love.filesystem.append then
		love.filesystem.append(BgaPreviewDebug.path, line .. "\n")
	end
end

return BgaPreviewDebug
