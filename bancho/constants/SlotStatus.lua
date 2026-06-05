local M = {}
M.OPEN = 1
M.LOCKED = 2
M.NOT_READY = 4
M.READY = 8
M.NO_MAP = 16
M.PLAYING = 32
M.COMPLETED = 64
M.QUIT = 128

-- Compatibility aliases for older local code paths.
M.LOADED = M.PLAYING
M.FAILED = M.QUIT

return M
