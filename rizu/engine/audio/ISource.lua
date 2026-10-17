local class = require("class")

---@class rizu.audio.ISource
---@operator call: rizu.audio.ISource
local ISource = class()

function ISource:release() end

function ISource:play() end

function ISource:pause() end

function ISource:update() end

---@return boolean
function ISource:isPlaying() return false end

---@param rate number
function ISource:setRate(rate) end

---@return number
function ISource:getPosition() return 0 end

---@param position number
function ISource:setPosition(position) end

---@return number
function ISource:getStartTime() return 0 end

---@return number
function ISource:getDuration() return 0 end

---@param volume number
function ISource:setVolume(volume) end

---@param size integer
function ISource:setFFTSize(size) end

---@return any
function ISource:getFFT() return nil end

return ISource
