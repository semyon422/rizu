local class = require("class")

---@class sea.ClientChartfileInsert
---@field id integer?
---@field hash string?
---@field name string
---@field path string?
---@field size integer?
---@field set_id integer
---@field modified_at number

---@class sea.ClientChartfile: sea.ClientChartfileInsert
---@operator call: sea.ClientChartfile
---@field id integer
local ClientChartfile = class()

return ClientChartfile
