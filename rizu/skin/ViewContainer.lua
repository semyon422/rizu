local View = require("rizu.skin.View")

---@class rizu.skin.ViewContainer : rizu.skin.View
---@operator call: rizu.skin.ViewContainer
---@overload fun(config: rizu.skin.View.Config): rizu.skin.ViewContainer
---@field children rizu.skin.View[] Children are drawn and updated in insertion order.
local ViewContainer = View + {}

---@param config rizu.skin.View.Config
function ViewContainer:new(config)
	View.new(self, config)
	self.children = {}
end

---@param view rizu.skin.View
---@return rizu.skin.ViewContainer
function ViewContainer:add(view)
	assert(View * view, "container child must be a skin View")
	assert(view ~= self, "a view cannot contain itself")
	assert(view.container == nil, "view already belongs to a container")
	local ancestor = self
	while ancestor do
		assert(ancestor ~= view, "adding this view would create a cycle")
		ancestor = ancestor.container
	end

	view.container = self
	self.children[#self.children + 1] = view
	if self.game then view:load(self.game) end
	return self
end

---@param view rizu.skin.View
---@return boolean removed
function ViewContainer:remove(view)
	for index, child in ipairs(self.children) do
		if child == view then
			if self.game then child:unload(self.game) end
			child.container = nil
			table.remove(self.children, index)
			return true
		end
	end
	return false
end

---@return rizu.skin.View[]
function ViewContainer:getChildren()
	return self.children
end

---@param game sphere.GameController
function ViewContainer:load(game)
	if self.game == game then return end
	if self.game then self:unload(self.game) end
	View.load(self, game)
	for _, child in ipairs(self.children) do child:load(game) end
end

---@param dt number
---@param game sphere.GameController
function ViewContainer:update(dt, game)
	if self.visible then
		View.update(self, dt, game)
		for _, child in ipairs(self.children) do child:update(dt, game) end
	end
end

---@param game sphere.GameController?
function ViewContainer:unload(game)
	game = game or self.game
	if game then
		for _, child in ipairs(self.children) do child:unload(game) end
	end
	View.unload(self, game)
end

---@param width number Parent viewport width in native coordinate units.
---@param height number Parent viewport height in native coordinate units.
---@param transform love.Transform? Transform from the parent viewport to drawing coordinates.
function ViewContainer:drawChildren(width, height, transform)
	for _, child in ipairs(self.children) do
		child:drawAtAnchors(width, height, transform)
	end
end

return ViewContainer
