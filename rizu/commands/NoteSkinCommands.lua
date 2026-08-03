---@param game sphere.GameController
---@return rizu.command.Fuzzy.Candidate[] choices
local function getNoteSkinChoices(game)
	local inputMode = tostring(game.modifierCoordinator.state.inputMode)
	---@type rizu.command.Fuzzy.Candidate[]
	local choices = {}

	if inputMode == "" then
		return choices
	end

	for _, skinInfo in ipairs(game.noteSkinModel:getSkinInfos(inputMode) or {}) do
		table.insert(choices, {
			title = skinInfo.name,
			value = skinInfo:getPath(),
		})
	end

	return choices
end

---@param game sphere.GameController
---@return rizu.command.Command[]
return function(game)
	return {
		{
			id = "noteskins.select",
			title = "Note Skins: Select",
			description = "Selects the default note skin for the current input mode",
			arguments = {
				{
					name = "path",
					type = "string",
					prompt = "Select note skin:",
					choices = function()
						return getNoteSkinChoices(game)
					end,
				},
			},
			callback = function(args)
				local inputMode = tostring(game.modifierCoordinator.state.inputMode)
				if inputMode ~= "" then
					game.noteSkinModel:setDefaultNoteSkin(inputMode, args.path)
					game.noteSkinModel:loadNoteSkin(inputMode)
				end
			end,
		},
	}
end
