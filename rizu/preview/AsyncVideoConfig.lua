---@class rizu.preview.AsyncVideoConfig: rizu.preview.AsyncVideoQueueConfig
---@field max_output_frames_per_update integer
---@field slow_main_seconds number
---@field worker_path string
local AsyncVideoConfig = {}

AsyncVideoConfig.buffer_target = 45
AsyncVideoConfig.buffer_low_watermark = 30
AsyncVideoConfig.max_output_frames_per_update = AsyncVideoConfig.buffer_target
AsyncVideoConfig.slow_main_seconds = 0.008
AsyncVideoConfig.worker_path = "rizu/preview/AsyncVideoWorker.lua"

return AsyncVideoConfig
