local class = require("class")

local lg = love.graphics

---@alias rizu.skin.ViewAnchor
---| "top_left"
---| "top"
---| "top_right"
---| "left"
---| "center"
---| "right"
---| "bottom_left"
---| "bottom"
---| "bottom_right"

---@class rizu.skin.View.Config
---@field anchor rizu.skin.ViewAnchor? Anchor point in the parent viewport.
---@field origin rizu.skin.ViewAnchor? Point on this view aligned to its anchor.
---@field x number? Offset from the anchor in native coordinate units.
---@field y number? Offset from the anchor in native coordinate units.
---@field width number View width in native coordinate units.
---@field height number View height in native coordinate units.
---@field transform love.Transform? Local transform applied around this view's origin.
---@field visible boolean? Whether this view is drawn. Defaults to true.

---@class rizu.skin.View
---@operator call: rizu.skin.View
---@overload fun(config: rizu.skin.View.Config): rizu.skin.View
---@field anchor rizu.skin.ViewAnchor
---@field origin rizu.skin.ViewAnchor
---@field x number
---@field y number
---@field width number
---@field height number
---@field transform love.Transform
---@field visible boolean
---@field game sphere.GameController?
---@field container rizu.skin.ViewContainer?
---@field _world_transform love.Transform?
local View = class()

local anchor_factors = {
	top_left = {0, 0},
	top = {0.5, 0},
	top_right = {1, 0},
	left = {0, 0.5},
	center = {0.5, 0.5},
	right = {1, 0.5},
	bottom_left = {0, 1},
	bottom = {0.5, 1},
	bottom_right = {1, 1},
}

View.anchors = anchor_factors

---@param value any
---@param name string
---@return number
local function finite_number(value, name)
	assert(type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge,
		name .. " must be a finite number")
	return value
end

---@param config rizu.skin.View.Config
function View:new(config)
	assert(type(config) == "table", "view config must be a table")
	assert(config.width ~= nil and config.height ~= nil, "view width and height are required")
	assert(config.transform == nil or type(config.transform) == "userdata" or type(config.transform) == "table",
		"view transform must be a love.Transform")

	self.anchor = config.anchor or "top_left"
	assert(anchor_factors[self.anchor], "view anchor is invalid")
	self.origin = config.origin or "top_left"
	assert(anchor_factors[self.origin], "view origin is invalid")
	self.x = finite_number(config.x == nil and 0 or config.x, "view x")
	self.y = finite_number(config.y == nil and 0 or config.y, "view y")
	self.width = finite_number(config.width, "view width")
	self.height = finite_number(config.height, "view height")
	assert(self.width >= 0 and self.height >= 0, "view dimensions must be non-negative")
	self.transform = config.transform or love.math.newTransform()
	self.visible = config.visible ~= false
	self.game = nil
	self.container = nil
	self._world_transform = nil
end

---@param game sphere.GameController
function View:load(game)
	if self.game == game then return end
	if self.game then self:unload(self.game) end
	self.game = game
end

---@param dt number
---@param game sphere.GameController
function View:update(dt, game) end

---@param game sphere.GameController?
function View:unload(game)
	if game == nil or game == self.game then self.game = nil end
end

---Override to draw in local coordinates, with the view's origin at (0, 0).
function View:draw() end

---@param width number Parent viewport width in native coordinate units.
---@param height number Parent viewport height in native coordinate units.
---@param transform love.Transform? Transform from the parent viewport to drawing coordinates.
function View:drawChildren(width, height, transform) end

---@param width number
---@param height number
---@param parent_transform love.Transform?
---@return love.Transform
function View:getWorldTransform(width, height, parent_transform)
	finite_number(width, "parent viewport width")
	finite_number(height, "parent viewport height")
	assert(width >= 0 and height >= 0, "parent viewport dimensions must be non-negative")

	local transform = self._world_transform
	if not transform then
		transform = love.math.newTransform()
		self._world_transform = transform
	end
	transform:reset()
	if parent_transform then transform:apply(parent_transform) end

	local anchor_factor = anchor_factors[self.anchor]
	local origin_factor = anchor_factors[self.origin]
	local origin_x = self.width * origin_factor[1]
	local origin_y = self.height * origin_factor[2]
	transform:translate(width * anchor_factor[1] + self.x - origin_x,
		height * anchor_factor[2] + self.y - origin_y)
	transform:translate(origin_x, origin_y)
	transform:apply(self.transform)
	transform:translate(-origin_x, -origin_y)
	return transform
end

---Draws this view and descendants in the parent's viewport coordinate system.
---@param width number Parent viewport width in native coordinate units.
---@param height number Parent viewport height in native coordinate units.
---@param parent_transform love.Transform? Transform from the parent viewport to drawing coordinates.
function View:drawAtAnchors(width, height, parent_transform)
	if not self.visible then return end
	local transform = self:getWorldTransform(width, height, parent_transform)
	lg.push("all")
	lg.replaceTransform(transform)
	self:draw()
	self:drawChildren(self.width, self.height, transform)
	lg.pop()
end

return View
