local AsyncVideoReadPolicy = {}

---@alias rizu.preview.AsyncVideoReadReason "initial"|"backward"|"jump"|"read"

---@param last_frame_time number?
---@param requested_time number?
---@param frame_rate number?
---@return boolean use_seek
---@return rizu.preview.AsyncVideoReadReason reason
function AsyncVideoReadPolicy.shouldSeek(last_frame_time, requested_time, frame_rate)
	if not requested_time then
		return false, "read"
	end
	if not last_frame_time then
		return true, "initial"
	end
	if requested_time < last_frame_time - 0.001 then
		return true, "backward"
	end

	local frame_duration = (frame_rate and frame_rate > 0 and 1 / frame_rate) or 1 / 30
	if requested_time - last_frame_time > frame_duration * 3 then
		return true, "jump"
	end
	return false, "read"
end

return AsyncVideoReadPolicy
