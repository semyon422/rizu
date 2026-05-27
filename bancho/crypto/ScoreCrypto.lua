--- Score encryption for osu! score submission.
---
--- Implements Rijndael-256 CBC encryption/decryption with PKCS7 padding.
--- The key derivation: "osu!-scoreburgr---------{osu_version}"
---
--- This is a stub implementation using a simple reversible cipher
--- for testing purposes. A real implementation would use libmbedcrypto
--- or a Lua port of Rijndael-256.

local class = require("class")

---@class bancho.crypto.ScoreCrypto
---@operator call: bancho.crypto.ScoreCrypto
local ScoreCrypto = class()

function ScoreCrypto:new()
	return self
end

--- Derive the encryption key from osu version.
---@param osu_version string
---@return string
function ScoreCrypto.deriveKey(osu_version)
	-- Key format: "osu!-scoreburgr---------{version}"
	-- Total key length is 32 bytes (Rijndael-256 block size)
	local prefix = "osu!-scoreburgr---------"
	return prefix .. osu_version
end

--- Encrypt score data (stub: XOR with key for testing).
--- Real implementation would use Rijndael-256 CBC.
---@param data string
---@param key string
---@param iv string
---@return string encrypted_data
function ScoreCrypto.encrypt(data, key, iv)
	-- Stub: XOR-based encryption for test compatibility
	-- Real implementation would use Rijndael-256 CBC with PKCS7 padding
	---@type string[]
	local out = {}
	local keyLen = #key
	local ivLen = #iv
	for i = 1, #data do
		local c = data:sub(i, i):byte()
		local k = key:sub(((i - 1) % keyLen) + 1, (i % keyLen) + 1):byte()
		table.insert(out, string.char(bit.bxor(c, k)))
	end
	return table.concat(out)
end

--- Decrypt score data (stub: XOR with key for testing).
--- Real implementation would use Rijndael-256 CBC.
---@param encrypted string
---@param key string
---@param iv string
---@return string decrypted_data
function ScoreCrypto.decrypt(encrypted, key, iv)
	-- Stub: XOR-based decryption for test compatibility
	---@type string[]
	local out = {}
	local keyLen = #key
	for i = 1, #encrypted do
		local c = encrypted:sub(i, i):byte()
		local k = key:sub(((i - 1) % keyLen) + 1, (i % keyLen) + 1):byte()
		table.insert(out, string.char(bit.bxor(c, k)))
	end
	return table.concat(out)
end

return ScoreCrypto
