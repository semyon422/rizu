--- Score encryption for osu! score submission.
---
--- Implements Rijndael-256 CBC encryption/decryption with PKCS7 padding.
--- The key derivation: "osu!-scoreburgr---------{osu_version}"
---
--- Uses OpenSSL FFI for real Rijndael-256 CBC implementation.

local Rijndael = require("bancho.crypto.Rijndael")

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
	return Rijndael.deriveKey(osu_version)
end

--- Encrypt score data.
--- Returns base64-encoded ciphertext.
---@param plaintext string
---@param key string
---@param iv_b64 string base64-encoded IV
---@return string? ciphertext_b64
---@return string? error
function ScoreCrypto.encrypt(plaintext, key, iv_b64)
	return Rijndael.encrypt(plaintext, key, iv_b64)
end

--- Decrypt score data.
--- Returns decrypted plaintext.
---@param ciphertext_b64 string base64-encoded ciphertext
---@param key string
---@param iv_b64 string base64-encoded IV
---@return string? plaintext
---@return string? error
function ScoreCrypto.decrypt(ciphertext_b64, key, iv_b64)
	return Rijndael.decrypt(ciphertext_b64, key, iv_b64)
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
	local key = ScoreCrypto.deriveKey(osu_version)

	-- Decrypt score data
	local score_data, err = ScoreCrypto.decrypt(score_data_b64, key, iv_b64)
	if not score_data then
		return nil, err
	end

	-- Decrypt client hash
	local client_hash, err2 = ScoreCrypto.decrypt(client_hash_b64, key, iv_b64)
	if not client_hash then
		return nil, err2
	end

	return score_data, client_hash
end

return ScoreCrypto
