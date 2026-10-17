---@class rizu.dlc.IDlcProvider
local IDlcProvider = {}

---@param query string
---@param filters table?
---@return table[]? results, string? error
function IDlcProvider:search(query, filters) end

---@param id string|number
---@return string? url, string? error
function IDlcProvider:getDownloadUrl(id) end

return IDlcProvider
