local brand = require("brand")

local prompt = assert(love.filesystem.read("rizu/ai/SystemPrompt.md"))
return (prompt:gsub("{{brand_name}}", brand.name))
