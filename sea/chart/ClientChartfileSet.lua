local class = require("class")

---@class sea.ClientChartfileSetInsert
---@field id integer?
---@field dir string?
---@field name string
---@field modified_at number
---@field is_file boolean
---@field location_id integer

---@class sea.ClientChartfileSet: sea.ClientChartfileSetInsert
---@operator call: sea.ClientChartfileSet
---@field id integer
local ClientChartfileSet = class()

return ClientChartfileSet
