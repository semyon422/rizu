--- Tests for bancho crypto ScoreCrypto (Rijndael-256 CBC).

local ScoreCrypto = require("bancho.crypto.ScoreCrypto")
local Rijndael = require("bancho.crypto.Rijndael")

local test = {}

function test.key_derivation(t)
	-- Key should be "osu!-scoreburgr---------{version}"
	local key = ScoreCrypto.deriveKey("20240101")
	t:eq(key:sub(1, 24), "osu!-scoreburgr---------")
	t:eq(key:sub(25), "20240101")
	t:eq(#key, 32) -- 24 + 8 = 32
end

function test.key_different_versions(t)
	local k1 = ScoreCrypto.deriveKey("20240101")
	local k2 = ScoreCrypto.deriveKey("20240102")
	t:eq(k1 ~= k2, true)
end

function test.encrypt_decrypt_roundtrip(t)
	local key = ScoreCrypto.deriveKey("20240101")
	-- IV must be 32 bytes, base64-encoded
	local iv = "abcdefghijklmnop" -- 16 bytes, will be zero-padded by OpenSSL
	local iv_padded = iv .. string.rep("\0", 32 - #iv)
	local iv_b64 = require("mime").b64(iv_padded)

	local data = "test:score:data"
	local encrypted = ScoreCrypto.encrypt(data, key, iv_b64)
	t:ne(encrypted, nil)
	t:ne(encrypted, data)

	local decrypted = ScoreCrypto.decrypt(encrypted, key, iv_b64)
	t:eq(decrypted, data)
end

function test.encrypt_produces_different_output(t)
	local key = ScoreCrypto.deriveKey("20240101")
	local iv_padded = "abcdefghijklmnop" .. string.rep("\0", 16)
	local iv_b64 = require("mime").b64(iv_padded)
	local data = "hello"
	local encrypted = ScoreCrypto.encrypt(data, key, iv_b64)
	t:ne(encrypted, nil)
	t:ne(encrypted, data)
end

function test.decryptScore(t)
	local key = ScoreCrypto.deriveKey("20240101")
	local iv_padded = "abcdefghijklmnop" .. string.rep("\0", 16)
	local iv_b64 = require("mime").b64(iv_padded)

	local score_data = "map_md5:username:n300:n100:n50"
	local client_hash = "client_hash_data_here"

	local score_b64 = ScoreCrypto.encrypt(score_data, key, iv_b64)
	local hash_b64 = ScoreCrypto.encrypt(client_hash, key, iv_b64)

	local decrypted_score, decrypted_hash = ScoreCrypto:decryptScore(score_b64, hash_b64, iv_b64, "20240101")
	t:eq(decrypted_score, score_data)
	t:eq(decrypted_hash, client_hash)
end

function test.rijndael_direct_encrypt_decrypt(t)
	local key = Rijndael.deriveKey("20240101")
	local iv_padded = "test_iv_123456789012345678901234"
	local iv_b64 = require("mime").b64(iv_padded)

	local plaintext = "test:score:100:50:25:10:5:3:123456:500:True:S:0:True:0:1234567890"
	local encrypted = Rijndael.encrypt(plaintext, key, iv_b64)
	t:ne(encrypted, nil)

	local decrypted = Rijndael.decrypt(encrypted, key, iv_b64)
	t:eq(decrypted, plaintext)
end

return test
