local class = require("class")

---@class rizu.preview.FakeBgaPreviewDebug: rizu.preview.BgaPreviewDebug
---@operator call: rizu.preview.FakeBgaPreviewDebug
---@field warnings any[][]
local FakeBgaPreviewDebug = class()

function FakeBgaPreviewDebug:new()
	self.warnings = {}
end

---@param ... any
function FakeBgaPreviewDebug:warn(...)
	table.insert(self.warnings, {...})
end

---@param state rizu.preview.AsyncVideoState
---@param name string
---@param kind string
---@param time number
---@param extra string?
function FakeBgaPreviewDebug:warnQueueState(state, name, kind, time, extra)
	self:warn("video_main", kind, name, time, #state.queue, extra)
end

---@param event rizu.preview.AsyncVideoFrameEvent
function FakeBgaPreviewDebug:warnMiss(event)
	self:warn("video_main", "miss", event.video_name, event.request_id, event.requested_time)
end

---@param name string
---@param prev_time number
---@param frame_time number
---@param queue_size integer
function FakeBgaPreviewDebug:warnNonMonotonic(name, prev_time, frame_time, queue_size)
	self:warn("video_main", "non_monotonic", name, prev_time, frame_time, queue_size)
end

---@param name string
---@param queue_size integer
---@param frame_time number
---@param elapsed number
function FakeBgaPreviewDebug:warnSlowPresent(name, queue_size, frame_time, elapsed)
	self:warn("video_main", "slow_present", name, queue_size, frame_time, elapsed)
end

---@param frame_events integer
---@param control_events integer
---@param elapsed number
function FakeBgaPreviewDebug:warnSlowUpdate(frame_events, control_events, elapsed)
	self:warn("video_main", "slow_update", frame_events, control_events, elapsed)
end

return FakeBgaPreviewDebug
