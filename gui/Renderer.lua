local class = require("class")

local DRAW_ITEM = 1

---@alias gui.RenderCommand 1

---@class gui.Renderer
---@operator call: gui.Renderer
---@field commands (gui.RenderCommand|gui.View)[] Packed command stream
---@field command_count integer
local Renderer = class()

function Renderer:new()
	---@type (gui.RenderCommand|gui.View)[]
	self.commands = {}
	self.command_count = 0
end

---Start rebuilding the packed command stream.
function Renderer:beginBuild()
	self.commands = {}
	self.command_count = 0
end

---@param view gui.View
function Renderer:addView(view)
	local index = self.command_count + 1
	local commands = self.commands
	commands[index] = DRAW_ITEM
	commands[index + 1] = view
	self.command_count = index + 1
end

function Renderer:clear()
	self.commands = {}
	self.command_count = 0
end

---Execute the cached command stream.
function Renderer:draw()
	local commands = self.commands
	local command_count = self.command_count
	local index = 1
	while index <= command_count do
		local command = commands[index]
		if command == DRAW_ITEM then
			local view = commands[index + 1]
			---@cast view gui.View
			if not view.detached and view.effective_visible and view.present then
				love.graphics.replaceTransform(view.world_transform)
				love.graphics.setScissor() -- clip_rect support lands with §9.1
				love.graphics.setColor(1, 1, 1, view.effective_opacity)
				view:draw()
			end
			index = index + 2
		else
			error(("unknown render command: %s"):format(tostring(command)))
		end
	end
	love.graphics.setScissor()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.origin()
end

return Renderer
