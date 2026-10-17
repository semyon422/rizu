---@alias gui.anim.EasingName
---| "Linear"
---| "InQuad"
---| "OutQuad"
---| "InOutQuad"
---| "InCubic"
---| "OutCubic"
---| "InOutCubic"
---| "InQuart"
---| "OutQuart"
---| "InOutQuart"
---| "InQuint"
---| "OutQuint"
---| "InOutQuint"
---| "InSine"
---| "OutSine"
---| "InOutSine"
---| "InExpo"
---| "OutExpo"
---| "InOutExpo"
---| "InCirc"
---| "OutCirc"
---| "InOutCirc"
---| "InBack"
---| "OutBack"
---| "InOutBack"
---| "InElastic"
---| "OutElastic"
---| "InOutElastic"
---| "InBounce"
---| "OutBounce"
---| "InOutBounce"
---| "OutElasticHalf"
---| "OutElasticQuarter"

---@alias gui.anim.EasingFamily "Quad"|"Cubic"|"Quart"|"Quint"|"Sine"|"Expo"|"Circ"|"Back"|"Elastic"
---@alias gui.anim.Easing fun(progress: number): number

local Easing = {}

local pi = math.pi
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local pow = math.pow

---@type {[gui.anim.EasingName]: gui.anim.Easing}
local easings = {}

---@param name gui.anim.EasingName
---@param fn gui.anim.Easing
local function add(name, fn)
	easings[name] = fn
end

add("Linear", function(t) return t end)

---@param name gui.anim.EasingFamily
---@param ease_in gui.anim.Easing
local function addFamily(name, ease_in)
	local ease_out = function(t)
		return 1 - ease_in(1 - t)
	end
	local ease_in_out = function(t)
		if t < 0.5 then
			return ease_in(t * 2) / 2
		end
		return 1 - ease_in((1 - t) * 2) / 2
	end
	---@type gui.anim.EasingName
	local in_name = "In" .. name
	---@type gui.anim.EasingName
	local out_name = "Out" .. name
	---@type gui.anim.EasingName
	local in_out_name = "InOut" .. name
	add(in_name, ease_in)
	add(out_name, ease_out)
	add(in_out_name, ease_in_out)
end

addFamily("Quad", function(t) return t * t end)
addFamily("Cubic", function(t) return t * t * t end)
addFamily("Quart", function(t) return t * t * t * t end)
addFamily("Quint", function(t) return t * t * t * t * t end)
addFamily("Sine", function(t) return 1 - cos(t * pi / 2) end)
addFamily("Expo", function(t) return t == 0 and 0 or pow(2, 10 * t - 10) end)
addFamily("Circ", function(t) return 1 - sqrt(1 - t * t) end)
addFamily("Back", function(t)
	local c1 = 1.70158
	return (c1 + 1) * t * t * t - c1 * t * t
end)
addFamily("Elastic", function(t)
	if t == 0 or t == 1 then return t end
	return -pow(2, 10 * t - 10) * sin((t * 10 - 10.75) * (2 * pi / 3))
end)

---@param t number
local function bounceOut(t)
	local n1 = 7.5625
	local d1 = 2.75
	if t < 1 / d1 then
		return n1 * t * t
	elseif t < 2 / d1 then
		t = t - 1.5 / d1
		return n1 * t * t + 0.75
	elseif t < 2.5 / d1 then
		t = t - 2.25 / d1
		return n1 * t * t + 0.9375
	end
	t = t - 2.625 / d1
	return n1 * t * t + 0.984375
end
add("OutBounce", bounceOut)
add("InBounce", function(t) return 1 - bounceOut(1 - t) end)
add("InOutBounce", function(t)
	if t < 0.5 then return (1 - bounceOut(1 - 2 * t)) / 2 end
	return (1 + bounceOut(2 * t - 1)) / 2
end)

-- Less oscillatory elastic variants used by restrained UI motion.
---@param cycles number
---@return gui.anim.Easing
local function dampedElasticOut(cycles)
	return function(t)
		if t == 0 or t == 1 then return t end
		return 1 - pow(2, -10 * t) * cos(t * pi * 2 * cycles)
	end
end
add("OutElasticHalf", dampedElasticOut(0.5))
add("OutElasticQuarter", dampedElasticOut(0.25))

---@param easing gui.anim.EasingName|gui.anim.Easing?
---@return gui.anim.Easing
function Easing.resolve(easing)
	if easing == nil then
		return easings.Linear
	end
	if type(easing) == "function" then
		return easing
	end
	local resolved = easings[easing]
	assert(resolved, ("unknown easing: %s"):format(tostring(easing)))
	return resolved
end

Easing.values = easings

return Easing
