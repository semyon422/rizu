local class = require("class")
local Fuzzy = require("yi.command_palette.Fuzzy")

---@class yi.command_palette.Argument
---@field name string
---@field type "string"|"number"|"boolean"
---@field prompt string?
---@field default any?
---@field choices yi.command_palette.Fuzzy.Candidate[]?
---@field validate (fun(val: string): boolean, string?)?

---@class yi.command_palette.Command
---@field id string
---@field title string
---@field description string?
---@field arguments yi.command_palette.Argument[]?
---@field callback fun(args: {[string]: any})

-- State machine handling command filtering, argument collection, and execution.
---@class yi.command_palette.PaletteState
---@operator call: yi.command_palette.PaletteState
---@field registry yi.command_palette.Registry
---@field query string
---@field active_command yi.command_palette.Command?
---@field current_arg_idx integer
---@field collected_args {[string]: any}
local PaletteState = class()

---@param registry yi.command_palette.Registry
function PaletteState:new(registry)
	self.registry = registry
	self.query = ""
	self.active_command = nil
	self.current_arg_idx = 0
	self.collected_args = {}
end


--- Resets the state machine back to standard command search mode.
function PaletteState:reset()
	self.query = ""
	self.active_command = nil
	self.current_arg_idx = 0
	self.collected_args = {}
end

--- Updates the search query string.
---@param query string
function PaletteState:setQuery(query)
	self.query = query
end

--- Checks if we are currently prompting the user for command arguments.
---@return boolean
function PaletteState:isArgumentMode()
	return self.active_command ~= nil
end

--- Gets the active prompt instructions (e.g. 'Search commands...' or parameter prompt).
---@return string
function PaletteState:getPromptText()
	if not self.active_command then
		return "Search commands..."
	end
	local arg_def = self.active_command.arguments[self.current_arg_idx]
	return arg_def.prompt or ("Enter " .. arg_def.name .. ":")
end

--- Returns the list of matching candidates (commands or choice options) based on query.
---@return (yi.command_palette.Command|yi.command_palette.Fuzzy.Candidate)[] candidates
function PaletteState:getCandidates()

	if not self.active_command then
		-- Commands mode: fuzzy filter list of active commands
		local commands = self.registry:getActiveCommands()
		return Fuzzy.filter(self.query, commands, "title")
	else
		-- Arguments mode
		local arg_def = self.active_command.arguments[self.current_arg_idx]
		if arg_def.choices then
			return Fuzzy.filter(self.query, arg_def.choices, "title")
		end
		return {} -- Text or number input (no static list choices)
	end
end

--- Cancels the current argument or closes the palette.
--- Go back one step in the argument chain, or exits argument mode.
--- Returns true if it went back, or false if it was already at the top (can be closed).
---@return boolean handled
function PaletteState:goBack()
	if not self.active_command then
		return false
	end

	if self.current_arg_idx > 1 then
		self.current_arg_idx = self.current_arg_idx - 1
		self.query = ""
		return true
	else
		self:reset()
		return true
	end
end

--- Confirms the current selection (either a command, a list choice, or free text).
---@param selected_item table? Optional item selected from getCandidates() list. If nil, uses free text query.
---@return boolean success If false, validation failed and we remain on the current step.
---@return string? error_msg Validation error message.
---@return boolean executed True if the final callback was executed and palette should close.
function PaletteState:confirmSelection(selected_item)
	if not self.active_command then
		-- Choosing a command
		local command = selected_item
		if not command then
			-- If nothing is selected, try to match first filtered command
			local filtered = self:getCandidates()
			command = filtered[1]
		end

		if not command then
			return false, "No matching command found", false
		end

		if command.arguments and #command.arguments > 0 then
			self.active_command = command
			self.current_arg_idx = 1
			self.query = ""
			self.collected_args = {}
			return true, nil, false
		else
			-- Run command immediately since it requires no parameters
			command.callback({})
			self:reset()
			return true, nil, true
		end
	else
		-- Resolving argument
		local arg_def = self.active_command.arguments[self.current_arg_idx]
		local val

		if arg_def.choices then
			local choice = selected_item
			if not choice then
				local filtered = self:getCandidates()
				choice = filtered[1]
			end
			if not choice then
				return false, "Please select an option from the list", false
			end
			val = choice.value
		else
			val = self.query
		end

		-- Validate raw string input
		if arg_def.validate then
			local ok, err = arg_def.validate(val)
			if not ok then
				return false, err or "Invalid input value", false
			end
		end

		-- Convert and store value
		local parsed_val = val
		if arg_def.type == "number" then
			parsed_val = tonumber(val)
			if not parsed_val then
				return false, "Must be a valid number", false
			end
		elseif arg_def.type == "boolean" then
			local l = tostring(val):lower()
			parsed_val = (l == "true" or l == "1" or l == "y" or l == "yes")
		end

		self.collected_args[arg_def.name] = parsed_val

		-- Move to next argument or execute
		if self.current_arg_idx < #self.active_command.arguments then
			self.current_arg_idx = self.current_arg_idx + 1
			self.query = ""
			return true, nil, false
		else
			self.active_command.callback(self.collected_args)
			self:reset()
			return true, nil, true
		end
	end
end

return PaletteState
