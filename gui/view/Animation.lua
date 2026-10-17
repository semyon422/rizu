local class = require("class")
local Easing = require("gui.anim.Easing")

---@class gui.Transform
---@field target string
---@field from number Read when the transform starts
---@field to number
---@field start number View-clock time
---@field duration number
---@field easing gui.anim.Easing
---@field on_complete (fun(view: gui.View))?

---The transform registry of a gui.View: tweens of its visual channel.
---Internal to gui; views expose it through their own methods.
local Animation = {}

---What a step changed; decides how much of the subtree has to be recomposed.
Animation.NONE = 0
Animation.OPACITY = 1
Animation.GEOMETRY = 2

local targets = {
	offset_x = true,
	offset_y = true,
	pivot_x = true,
	pivot_y = true,
	rotation = true,
	scale_x = true,
	scale_y = true,
	opacity = true,
}

---@param target any
local function assertTarget(target)
	assert(targets[target], ("invalid transform target: %s"):format(tostring(target)))
end

---@param view gui.View
---@param target string
---@return number
local function getValue(view, target)
	if target == "pivot_x" then return view.pivot[1] end
	if target == "pivot_y" then return view.pivot[2] end
	return view[target]
end

---@param view gui.View
---@param target string
---@param value number
local function setValue(view, target, value)
	if target == "pivot_x" then
		view.pivot[1] = value
	elseif target == "pivot_y" then
		view.pivot[2] = value
	elseif target == "opacity" then
		view.opacity = math.max(0, math.min(1, value))
	else
		view[target] = value ---@diagnostic disable-line
	end
end

---@param completions any[]? Flat {view, callback, ...} list, created on first use
---@param view gui.View
---@param on_complete (fun(view: gui.View))?
---@return any[]? completions
local function addCompletion(completions, view, on_complete)
	if not on_complete then
		return completions
	end
	completions = completions or {}
	completions[#completions + 1] = view
	completions[#completions + 1] = on_complete
	return completions
end

---@param completions any[]?
function Animation.runCompletions(completions)
	if not completions then
		return
	end
	for i = 1, #completions, 2 do
		completions[i + 1](completions[i])
	end
end

---@param view gui.View
---@param target string?
local function dropPending(view, target)
	local pending = view.pending_transforms
	if not pending then
		return
	end
	for i = #pending, 1, -1 do
		if target == nil or pending[i].target == target then
			table.remove(pending, i)
		end
	end
	if not pending[1] then
		view.pending_transforms = nil
	end
end

---@param view gui.View
---@param target string
---@param to number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@param on_complete (fun(view: gui.View))?
---@param start number? View-clock time to start at; starts now when omitted
function Animation.transformTo(view, target, to, duration, easing, on_complete, start)
	assertTarget(target)
	assert(type(to) == "number" and to == to and math.abs(to) < math.huge, "transform target value must be finite")
	assert(type(duration) == "number" and duration >= 0 and duration < math.huge, "transform duration must be finite and non-negative")
	assert(on_complete == nil or type(on_complete) == "function", "transform completion must be a function or nil")
	local now = view.animation_time
	---@type gui.Transform
	local transform = {
		target = target,
		from = 0,
		to = to,
		start = start or now,
		duration = duration,
		easing = Easing.resolve(easing),
		on_complete = on_complete,
	}
	if transform.start > now then
		-- Waits its turn: the running transform keeps going and `from` is read at the start time.
		local pending = view.pending_transforms or {}
		local index = #pending + 1
		while index > 1 and pending[index - 1].start > transform.start do
			index = index - 1
		end
		table.insert(pending, index, transform)
		view.pending_transforms = pending
	else
		dropPending(view, target)
		if duration == 0 then
			setValue(view, target, to)
			view.transforms[target] = nil
			view:composeSubtree(target == "opacity")
			if on_complete then on_complete(view) end
			view:checkExpired()
			return
		end
		transform.from = getValue(view, target)
		view.transforms[target] = transform
	end
	if view.screen then
		view.screen:trackAnimation(view)
	end
end

---Advance the view clock and apply every running transform. Does not recompose and does not
---call completions: the caller does both once all views of the frame are stepped.
---@param view gui.View
---@param dt number
---@param completions any[]?
---@return integer kind Animation.NONE|OPACITY|GEOMETRY
---@return any[]? completions
function Animation.step(view, dt, completions)
	local now = view.animation_time + dt
	view.animation_time = now
	local kind = Animation.NONE
	local transforms = view.transforms

	local pending = view.pending_transforms
	if pending then
		while pending[1] and pending[1].start <= now do
			local transform = table.remove(pending, 1) ---@type gui.Transform
			local target = transform.target
			local running = transforms[target]
			if running and running.start + running.duration <= transform.start then
				-- The predecessor ended before this one began, so it gets to finish.
				setValue(view, target, running.to)
				completions = addCompletion(completions, view, running.on_complete)
			end
			transform.from = getValue(view, target)
			transforms[target] = transform
		end
		if not pending[1] then
			view.pending_transforms = nil
		end
	end

	for target, transform in pairs(transforms) do
		local progress = 1
		if transform.duration > 0 then
			progress = math.min(1, (now - transform.start) / transform.duration)
		end
		if progress >= 1 then
			setValue(view, target, transform.to)
			transforms[target] = nil
			completions = addCompletion(completions, view, transform.on_complete)
		else
			setValue(view, target, transform.from + (transform.to - transform.from) * transform.easing(progress))
		end
		kind = math.max(kind, target == "opacity" and Animation.OPACITY or Animation.GEOMETRY)
	end
	return kind, completions
end

---@param view gui.View
---@return boolean
function Animation.has(view)
	return next(view.transforms) ~= nil or view.pending_transforms ~= nil
end

---View-clock time at which everything scheduled so far has ended.
---@param view gui.View
---@return number
function Animation.latestEnd(view)
	local latest = view.animation_time
	for _, transform in pairs(view.transforms) do
		latest = math.max(latest, transform.start + transform.duration)
	end
	for _, transform in ipairs(view.pending_transforms or {}) do
		latest = math.max(latest, transform.start + transform.duration)
	end
	return latest
end

---Jump running and delayed transforms to their end values and complete them.
---@param view gui.View
---@param target string?
function Animation.finish(view, target)
	if target ~= nil then assertTarget(target) end
	local completions ---@type any[]?
	local changed = false
	local transforms = view.transforms
	for transform_target, transform in pairs(transforms) do
		if target == nil or target == transform_target then
			setValue(view, transform_target, transform.to)
			transforms[transform_target] = nil
			changed = true
			completions = addCompletion(completions, view, transform.on_complete)
		end
	end
	for _, transform in ipairs(view.pending_transforms or {}) do
		if target == nil or target == transform.target then
			setValue(view, transform.target, transform.to)
			changed = true
			completions = addCompletion(completions, view, transform.on_complete)
		end
	end
	dropPending(view, target)
	if changed then view:composeSubtree() end
	Animation.runCompletions(completions)
	view:checkExpired()
end

---Drop running and delayed transforms without applying or completing them.
---@param view gui.View
---@param target string?
function Animation.clear(view, target)
	if target ~= nil then
		assertTarget(target)
		view.transforms[target] = nil
	else
		view.transforms = {}
	end
	dropPending(view, target)
	view:checkExpired()
end

---Returned by `View:delay()`. Animations started through it begin at the delayed time.
---The view itself keeps no delay state, so later calls on the view are unaffected.
---@class gui.view.Animation.Delayed
---@operator call: gui.view.Animation.Delayed
---@field view gui.View
---@field start number View-clock time
local Delayed = class()

---@param view gui.View
---@param duration number
function Delayed:new(view, duration)
	self.view = view
	self.start = view.animation_time
	self:delay(duration)
end

---Wait `duration` after everything scheduled so far has ended.
---@param duration number
---@return gui.view.Animation.Delayed
function Delayed:delay(duration)
	assert(type(duration) == "number" and duration >= 0 and duration < math.huge, "delay must be finite and non-negative")
	self.start = math.max(self.start, Animation.latestEnd(self.view)) + duration
	return self
end

---@param target string
---@param to number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@param on_complete (fun(view: gui.View))?
---@return gui.view.Animation.Delayed
function Delayed:transformTo(target, to, duration, easing, on_complete)
	Animation.transformTo(self.view, target, to, duration, easing, on_complete, self.start)
	return self
end

---@param alpha number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.view.Animation.Delayed
function Delayed:fadeTo(alpha, duration, easing)
	assert(alpha >= 0 and alpha <= 1, "opacity must be between 0 and 1")
	return self:transformTo("opacity", alpha, duration, easing)
end

---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.view.Animation.Delayed
function Delayed:fadeIn(duration, easing)
	return self:fadeTo(1, duration, easing or "OutQuint")
end

---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.view.Animation.Delayed
function Delayed:fadeOut(duration, easing)
	return self:fadeTo(0, duration, easing or "OutQuad")
end

---@param x number
---@param y number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.view.Animation.Delayed
function Delayed:moveTo(x, y, duration, easing)
	return self:transformTo("offset_x", x, duration, easing):transformTo("offset_y", y, duration, easing)
end

---@param x number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.view.Animation.Delayed
function Delayed:moveToX(x, duration, easing)
	return self:transformTo("offset_x", x, duration, easing)
end

---@param y number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.view.Animation.Delayed
function Delayed:moveToY(y, duration, easing)
	return self:transformTo("offset_y", y, duration, easing)
end

---@param pivot_x number
---@param pivot_y number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.view.Animation.Delayed
function Delayed:pivotTo(pivot_x, pivot_y, duration, easing)
	return self:transformTo("pivot_x", pivot_x, duration, easing):transformTo("pivot_y", pivot_y, duration, easing)
end

---@param scale_x number
---@param scale_y number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.view.Animation.Delayed
function Delayed:scaleTo(scale_x, scale_y, duration, easing)
	return self:transformTo("scale_x", scale_x, duration, easing):transformTo("scale_y", scale_y, duration, easing)
end

---@param rotation number
---@param duration number
---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.view.Animation.Delayed
function Delayed:rotateTo(rotation, duration, easing)
	return self:transformTo("rotation", rotation, duration, easing)
end

Animation.Delayed = Delayed

return Animation
