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

--- Decrypt score submission data.
--- The score data is base64-encoded, then AES-encrypted.
--- Returns the decrypted score fields and client hash.
---@param score_data_b64 string base64-encoded encrypted score data
---@param client_hash_b64 string base64-encoded client hash
---@param iv_b64 string base64-encoded IV
---@param osu_version string osu! client version
---@return string? score_data decrypted score data (colon-delimited)
---@return string? client_hash decoded client hash
function ScoreCrypto:decryptScore(score_data_b64, client_hash_b64, iv_b64, osu_version)
	local mime = require("mime")

	-- Decode base64
	local score_data_enc = mime.unb64(score_data_b64)
	local iv_enc = mime.unb64(iv_b64)

	-- Derive key
	local key = ScoreCrypto.deriveKey(osu_version)

	-- Decrypt score data (the last 32 bytes are the client hash)
	local decrypted = ScoreCrypto.decrypt(score_data_enc, key, iv_enc)
	if not decrypted or #decrypted < 32 then
		return nil, nil
	end

	-- Extract client hash from end of decrypted data
	local score_data = decrypted:sub(1, #decrypted - 32)
	local client_hash = decrypted:sub(-32)

	return score_data, client_hash
end

return ScoreCrypto
