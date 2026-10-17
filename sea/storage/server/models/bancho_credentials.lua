local BanchoCredential = require("sea.access.BanchoCredential")

---@type rdb.ModelOptions
local bancho_credentials = {}

bancho_credentials.metatable = BanchoCredential

return bancho_credentials
