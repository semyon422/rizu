--- Tests for bancho crypto Rijndael (Rijndael-256 CBC).

local Rijndael = require("bancho.crypto.Rijndael")
local mime = require("mime")

local test = {}

--- py3rijndael reference vector: key + plaintext -> ciphertext.
function test.py3rijndael_test_vector(t)
	local key_b64 = "qBS8uRhEIBsr8jr8vuY9uUpGFefYRL2HSTtrKhaI1tk="
	local key = mime.unb64(key_b64)

	local cipher = Rijndael.Rijndael.new(key, 32)
	local plaintext = "Mahdi" .. string.rep(string.char(0x1B), 27)

	local encrypted = cipher:encrypt(plaintext)
	t:eq(mime.b64(encrypted), "Kc8C3vjf+EpLRmgTZ5ckWTzJ/6n7WBHW8pkByDscI/E=")

	local decrypted = cipher:decrypt(encrypted)
	t:eq(decrypted, plaintext)
end

--- Encrypt then decrypt a single block with Rijndael-256.
function test.single_block_roundtrip(t)
	local key = string.rep("\0", 32)
	local cipher = Rijndael.Rijndael.new(key, 32)

	local plaintext = "HelloWorld1234567890123456789012" -- 32 bytes
	t:eq(#plaintext, 32)

	local encrypted = cipher:encrypt(plaintext)
	t:ne(encrypted, plaintext)

	local decrypted = cipher:decrypt(encrypted)
	t:eq(decrypted, plaintext)
end

--- All-zero block encrypts to non-zero.
function test.all_zero_block(t)
	local key = string.rep("\0", 32)
	local cipher = Rijndael.Rijndael.new(key, 32)

	local plaintext = string.rep("\0", 32)
	local encrypted = cipher:encrypt(plaintext)

	-- Ciphertext should not be all zeros
	for i = 1, 32 do
		if encrypted:byte(i) ~= 0 then
			return -- at least one byte is non-zero
		end
	end
	t:eq(true, false, "encrypted all-zero block produced all-zero output")
end

--- Decrypt the known ciphertext from py3rijndael.
function test.decrypt_py3rijndael_ciphertext(t)
	local key_b64 = "qBS8uRhEIBsr8jr8vuY9uUpGFefYRL2HSTtrKhaI1tk="
	local key = mime.unb64(key_b64)

	local cipher = Rijndael.Rijndael.new(key, 32)
	local ct = mime.unb64("Kc8C3vjf+EpLRmgTZ5ckWTzJ/6n7WBHW8pkByDscI/E=")

	local decrypted = cipher:decrypt(ct)
	t:eq(decrypted, "Mahdi" .. string.rep(string.char(0x1B), 27))
end

--- CBC mode encrypt/decrypt with PKCS7 padding.
function test.cbc_roundtrip(t)
	local key = Rijndael.deriveKey("20240101")
	local iv = string.rep("A", 32)

	local cbc = Rijndael.RijndaelCbc.new(key, iv, 32)
	local plaintext = "test:score:data"

	local encrypted = cbc:encrypt(plaintext)
	t:ne(encrypted, plaintext)
	t:eq(#encrypted % 32, 0) -- must be multiple of block size

	local decrypted = cbc:decrypt(encrypted)
	t:eq(decrypted, plaintext)
end

--- CBC with data exactly one block.
function test.cbc_one_block(t)
	local key = Rijndael.deriveKey("20240101")
	local iv = string.rep("B", 32)

	local cbc = Rijndael.RijndaelCbc.new(key, iv, 32)
	local plaintext = string.rep("X", 32) -- exactly one block

	local encrypted = cbc:encrypt(plaintext)
	-- PKCS7 pads one full block -> 64 bytes
	t:eq(#encrypted, 64)

	local decrypted = cbc:decrypt(encrypted)
	t:eq(decrypted, plaintext)
end

--- CBC with data spanning multiple blocks.
function test.cbc_multi_block(t)
	local key = Rijndael.deriveKey("20240101")
	local iv = string.rep("C", 32)

	local cbc = Rijndael.RijndaelCbc.new(key, iv, 32)
	local plaintext = string.rep("A", 100) -- spans 4 blocks (3 full + 1 partial)

	local encrypted = cbc:encrypt(plaintext)
	t:eq(#encrypted, 128) -- 4 blocks * 32 bytes

	local decrypted = cbc:decrypt(encrypted)
	t:eq(decrypted, plaintext)
end

--- Different IV produces different ciphertext.
function test.cbc_different_iv(t)
	local key = Rijndael.deriveKey("20240101")
	local plaintext = "hello world"

	local iv1 = string.rep("A", 32)
	local iv2 = string.rep("B", 32)

	local cbc1 = Rijndael.RijndaelCbc.new(key, iv1, 32)
	local cbc2 = Rijndael.RijndaelCbc.new(key, iv2, 32)

	local ct1 = cbc1:encrypt(plaintext)
	local ct2 = cbc2:encrypt(plaintext)
	t:ne(ct1, ct2)
end

--- Same IV produces same ciphertext (deterministic).
function test.cbc_deterministic(t)
	local key = Rijndael.deriveKey("20240101")
	local iv = string.rep("D", 32)
	local plaintext = "deterministic test"

	local cbc1 = Rijndael.RijndaelCbc.new(key, iv, 32)
	local cbc2 = Rijndael.RijndaelCbc.new(key, iv, 32)

	local ct1 = cbc1:encrypt(plaintext)
	local ct2 = cbc2:encrypt(plaintext)
	t:eq(ct1, ct2)
end

--- Module-level encrypt/decrypt with base64.
function test.module_encrypt_decrypt(t)
	local key = Rijndael.deriveKey("20240101")
	local iv = string.rep("E", 32)
	local iv_b64 = mime.b64(iv)

	local plaintext = "map_md5:username:300:100:50"
	local ct_b64 = Rijndael.encrypt(plaintext, key, iv_b64)
	t:ne(ct_b64, nil)

	local decrypted = Rijndael.decrypt(ct_b64, key, iv_b64)
	t:eq(decrypted, plaintext)
end

--- Module-level encrypt returns nil for bad IV.
function test.encrypt_bad_iv(t)
	local key = Rijndael.deriveKey("20240101")
	local short_iv = mime.b64("short")

	local ct, err = Rijndael.encrypt("data", key, short_iv)
	t:eq(ct, nil)
	t:ne(err, nil)
end

--- Module-level decrypt returns nil for bad IV.
function test.decrypt_bad_iv(t)
	local key = Rijndael.deriveKey("20240101")
	local short_iv = mime.b64("short")

	local pt, err = Rijndael.decrypt("dGFzdA==", key, short_iv)
	t:eq(pt, nil)
	t:ne(err, nil)
end

--- Key derivation produces correct format.
function test.derive_key(t)
	local key = Rijndael.deriveKey("20240101")
	t:eq(#key, 32)
	t:eq(key:sub(1, 24), "osu!-scoreburgr---------")
	t:eq(key:sub(25), "20240101")
end

--- Key derivation with different versions.
function test.derive_key_different_versions(t)
	local k1 = Rijndael.deriveKey("20231225")
	local k2 = Rijndael.deriveKey("20240101")
	t:ne(k1, k2)
end

--- Rijndael-128 (block_size=16) still works.
function test.rijndael_128_roundtrip(t)
	local key = string.rep("\0", 16)
	local cipher = Rijndael.Rijndael.new(key, 16)

	local plaintext = "1234567890123456"
	local encrypted = cipher:encrypt(plaintext)
	local decrypted = cipher:decrypt(encrypted)
	t:eq(decrypted, plaintext)
end

--- Rijndael-192 (block_size=24) still works.
function test.rijndael_192_roundtrip(t)
	local key = string.rep("\0", 24)
	local cipher = Rijndael.Rijndael.new(key, 24)

	local plaintext = string.rep("A", 24)
	local encrypted = cipher:encrypt(plaintext)
	local decrypted = cipher:decrypt(encrypted)
	t:eq(decrypted, plaintext)
end

--- Invalid block size errors.
function test.invalid_block_size(t)
	local key = string.rep("\0", 32)
	local ok, err = pcall(function()
		Rijndael.Rijndael.new(key, 12)
	end)
	t:eq(ok, false)
	t:ne(err, nil)
end

--- Invalid key size errors.
function test.invalid_key_size(t)
	local ok, err = pcall(function()
		Rijndael.Rijndael.new("short", 32)
	end)
	t:eq(ok, false)
	t:ne(err, nil)
end

--- Wrong block length in encrypt errors.
function test.encrypt_wrong_block_length(t)
	local key = string.rep("\0", 32)
	local cipher = Rijndael.Rijndael.new(key, 32)

	local ok, err = pcall(function()
		cipher:encrypt("too short")
	end)
	t:eq(ok, false)
	t:ne(err, nil)
end

--- Wrong block length in decrypt errors.
function test.decrypt_wrong_block_length(t)
	local key = string.rep("\0", 32)
	local cipher = Rijndael.Rijndael.new(key, 32)

	local ok, err = pcall(function()
		cipher:decrypt("too short")
	end)
	t:eq(ok, false)
	t:ne(err, nil)
end

--- CBC decrypt rejects non-multiple-of-block-size input.
function test.cbc_decrypt_bad_length(t)
	local key = Rijndael.deriveKey("20240101")
	local iv = string.rep("F", 32)

	local cbc = Rijndael.RijndaelCbc.new(key, iv, 32)
	local ok, err = pcall(function()
		cbc:decrypt("not multiple of 32")
	end)
	t:eq(ok, false)
	t:ne(err, nil)
end

--- PKCS7 padding: data exactly at block boundary gets full block of padding.
function test.pkcs7_full_block_padding(t)
	local key = Rijndael.deriveKey("20240101")
	local iv = string.rep("G", 32)

	local cbc = Rijndael.RijndaelCbc.new(key, iv, 32)
	local plaintext = string.rep("P", 32) -- exactly one block
	local encrypted = cbc:encrypt(plaintext)
	-- Should be 2 blocks (data + padding block)
	t:eq(#encrypted, 64)

	local decrypted = cbc:decrypt(encrypted)
	t:eq(decrypted, plaintext)
end

--- PKCS7 padding: empty-ish data.
function test.pkcs7_small_data(t)
	local key = Rijndael.deriveKey("20240101")
	local iv = string.rep("H", 32)

	local cbc = Rijndael.RijndaelCbc.new(key, iv, 32)
	local plaintext = "x" -- single byte

	local encrypted = cbc:encrypt(plaintext)
	t:eq(#encrypted, 32) -- one block with 1 byte data + 31 bytes padding

	local decrypted = cbc:decrypt(encrypted)
	t:eq(decrypted, plaintext)
end

--- Binary data roundtrip.
function test.binary_data_roundtrip(t)
	local key = Rijndael.deriveKey("20240101")
	local iv = string.rep("I", 32)

	local cbc = Rijndael.RijndaelCbc.new(key, iv, 32)
	local plaintext = string.char(0, 1, 2, 127, 128, 255, 0, 0)

	local encrypted = cbc:encrypt(plaintext)
	local decrypted = cbc:decrypt(encrypted)
	t:eq(decrypted, plaintext)
end

--- Cross-key decrypt fails (different key produces garbage).
function test.wrong_key_decrypt(t)
	local key1 = Rijndael.deriveKey("20240101")
	local key2 = Rijndael.deriveKey("20240102")
	local iv = string.rep("J", 32)

	local cbc1 = Rijndael.RijndaelCbc.new(key1, iv, 32)
	local cbc2 = Rijndael.RijndaelCbc.new(key2, iv, 32)

	local plaintext = "secret data"
	local encrypted = cbc1:encrypt(plaintext)

	local decrypted = cbc2:decrypt(encrypted)
	t:ne(decrypted, plaintext)
end

return test
