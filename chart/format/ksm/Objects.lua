local Objects = {}

---@param chart chart.Chart
---@return chart.ksm.SdvxButton[]
---@return chart.ksm.SdvxLaser[]
function Objects.get(chart)
	---@type chart.ksm.SdvxButton[]
	local buttons = {}
	---@type chart.ksm.SdvxLaser[]
	local lasers = {}
	for _, note in chart.notes:iter() do
		if note.type == "sdvx:button" then
			buttons[#buttons + 1] = note.data
		elseif note.type == "sdvx:laser" then
			lasers[#lasers + 1] = note.data
		end
	end
	return buttons, lasers
end

return Objects
