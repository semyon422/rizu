local ActionSchema = require("rizu.build.deps.spec.ActionSchema")

---@class rizu.build.deps.spec.SpecValidator
local SpecValidator = {}

local step_kinds = {
	archive = true,
	git = true,
	["source-build"] = true,
}

---@param step rizu.build.deps.Step
local function validateStep(step)
	if type(step) ~= "table" then
		error("Step must be a table")
	end
	if not step.id then
		error("Step is missing required field 'id'")
	end
	if not step.kind then
		error("Step '" .. tostring(step.id) .. "' is missing required field 'kind'")
	end
	if not step_kinds[step.kind] then
		error("Step '" .. tostring(step.id) .. "' has unsupported kind '" .. tostring(step.kind) .. "'")
	end
	if type(step.actions) ~= "table" then
		error("Step '" .. tostring(step.id) .. "' must define actions table")
	end
	for _, action in ipairs(step.actions) do
		ActionSchema.validate(action, step)
	end
	if type(step.outputs) ~= "table" then
		error("Step '" .. tostring(step.id) .. "' must define outputs table")
	end
	if type(step.inputs) ~= "table" then
		error("Step '" .. tostring(step.id) .. "' must define inputs table")
	end
end

---@param spec rizu.build.deps.Spec
function SpecValidator.validate(spec)
	if type(spec) ~= "table" then
		error("Spec must be a table")
	end
	if type(spec.steps) ~= "table" then
		error("Spec is missing steps table")
	end
	---@type {[string]: true}
	local ids = {}
	for _, step in ipairs(spec.steps) do
		validateStep(step)
		if ids[step.id] then
			error("Duplicate step id in spec: " .. tostring(step.id))
		end
		ids[step.id] = true
	end
end

return SpecValidator
