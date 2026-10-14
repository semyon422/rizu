local Events = require("rizu.api.Events")

---`rizu.api.Online` for a logged in player with no avatar.
---@class rizu.api.fake.FakeOnline : rizu.api.Events
---@operator call: rizu.api.fake.FakeOnline
local FakeOnline = Events + {}

function FakeOnline:isConnected() return true end
function FakeOnline:getUsername() return "Player" end
function FakeOnline:getAvatarUrl() return nil end
function FakeOnline:getOnlineCount() return 42 end
function FakeOnline:getAvatar(url) return nil end
function FakeOnline:login(email, password, f) f(true) end
function FakeOnline:logout() end

return FakeOnline
