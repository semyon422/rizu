--- Tests for bancho crypto ScoreCrypto (stub).

local ScoreCrypto = require("bancho.crypto.ScoreCrypto")

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
	local iv = "\000\000\000\000\000\000\000\000"
	local data = "test|data|to|encrypt"
	local encrypted = ScoreCrypto.encrypt(data, key, iv)
	t:eq(#encrypted, #data) -- same length for XOR

	local decrypted = ScoreCrypto.decrypt(encrypted, key, iv)
	t:eq(decrypted, data)
end

function test.encrypt_produces_different_output(t)
	local key = ScoreCrypto.deriveKey("20240101")
	local iv = "\000\000\000\000\000\000\000\000"
	local data = "hello"
	local encrypted = ScoreCrypto.encrypt(data, key, iv)
	t:eq(encrypted ~= data, true) -- should be different from plaintext
end

return test
