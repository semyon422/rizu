---@class rizu.skin.stepmania.Environment
local Environment = {}

---@param source string
---@param source_path string
---@param variables table?
---@param resolve_actor fun(path: {button: string, element: string}, depth: integer?): {button: string, element: string}?, table?
---@param resolve_element fun(button: string, element: string): string, string
---@param get_metric fun(group: string, name: string): string
---@param depth integer?
---@return table?
function Environment.load(source, source_path, variables, resolve_actor, resolve_element, get_metric, depth)
	local actor_meta = {
		__concat = function(left, right)
			if type(left) ~= "table" then return right end
			if type(right) == "table" then
				for name, value in pairs(right) do left[name] = value end
			end
			return left
		end,
	}
	local function actor_table(actor)
		return setmetatable(actor, actor_meta)
	end
	local function note_skin_path(button, element)
		return {button = button, element = element}
	end
	local function load_actor(actor_path, ...)
		local texture, actor
		if type(actor_path) == "table" then
			texture, actor = resolve_actor(actor_path, (depth or 0) + 1)
		elseif type(actor_path) == "string" then
			texture = note_skin_path("", actor_path)
			actor = actor_table({Texture = texture, __loaded_asset = actor_path})
		end
		if texture then return actor or actor_table({Texture = texture}) end
		for i = 1, select("#", ...) do
			local child = select(i, ...)
			if type(child) == "table" and type(child.Texture) == "table" then return child end
		end
	end
	local env = {
		Var = function(name) return variables and variables[name] end,
		NOTESKIN = {
			GetPath = function(_, button, element) return note_skin_path(button, element) end,
			GetMetricA = function(_, group, name) return get_metric(group, name) end,
			LoadActor = function(_, button, element)
				local resolved_button, resolved_element = resolve_element(button, element)
				return load_actor(note_skin_path(resolved_button, resolved_element))
			end,
		},
		LoadActor = load_actor,
		cmd = function(...)
			local parts = {}
			for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
			return table.concat(parts, ",")
		end,
		Sprite = {LinearFrames = function() return nil end},
		Def = setmetatable({}, {__index = function() return function(actor) return actor_table(actor) end end}),
		string = string,
		table = table,
		math = math,
		pairs = pairs,
		ipairs = ipairs,
		type = type,
		tonumber = tonumber,
		tostring = tostring,
		select = select,
	}
	local chunk = loadstring(source, "@" .. source_path)
	if not chunk then return end
	setfenv(chunk, env)
	local ok, actor = pcall(chunk)
	if ok and type(actor) == "table" then return actor end
end

return Environment
