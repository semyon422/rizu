local class = require("class")

---@class chart.sph.LineNote
---@field column integer
---@field type string

---@class chart.sph.Line
---@operator call: chart.sph.Line
---@field comment string?
---@field notes chart.sph.LineNote[]?
---@field offset number?
---@field time chart.Fraction?
---@field same true?
---@field visual string?
---@field measure chart.Fraction?
---@field sounds integer[]?
---@field volume integer[]?
---@field velocity number[]?
---@field expand number?
local Line = class()

return Line
