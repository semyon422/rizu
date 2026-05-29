--- Rijndael-256 CBC encryption/decryption using OpenSSL FFI.
---
--- Implements the osu! score submission encryption scheme:
--- Rijndael-256 CBC with PKCS7 padding, block size 32.

local ffi = require("ffi")
local mime = require("mime")

-- Load OpenSSL crypto library
local C = ffi.load("crypto")

ffi.cdef[[
    void *EVP_CIPHER_CTX_new();
    void EVP_CIPHER_CTX_free(void *ctx);
    const void *EVP_aes_256_cbc();
    int EVP_EncryptInit_ex(void *ctx, const void *cipher, void *impl, const unsigned char *key, const unsigned char *iv);
    int EVP_EncryptUpdate(void *ctx, unsigned char *out, int *outl, const unsigned char *in, int inl);
    int EVP_EncryptFinal_ex(void *ctx, unsigned char *out, int *outl);
    int EVP_DecryptInit_ex(void *ctx, const void *cipher, void *impl, const unsigned char *key, const unsigned char *iv);
    int EVP_DecryptUpdate(void *ctx, unsigned char *out, int *outl, const unsigned char *in, int inl);
    int EVP_DecryptFinal_ex(void *ctx, unsigned char *out, int *outl);
]]

--- Encrypt plaintext using Rijndael-256 CBC.
--- Returns base64-encoded ciphertext.
---@param plaintext string
---@param key string 32-byte key
---@param iv string 32-byte IV
---@return string? ciphertext_b64
---@return string? error
local function encrypt(plaintext, key, iv)
    local ctx = C.EVP_CIPHER_CTX_new()
    if not ctx then return nil, "failed to create cipher context" end

    local ret = C.EVP_EncryptInit_ex(ctx, C.EVP_aes_256_cbc(), nil, key, iv)
    if ret ~= 1 then
        C.EVP_CIPHER_CTX_free(ctx)
        return nil, "EncryptInit failed"
    end

    -- Allocate output buffer (input + one block for padding)
    local out = ffi.new("uint8_t[?]", #plaintext + 32)
    local outl = ffi.new("int[1]", 0)

    ret = C.EVP_EncryptUpdate(ctx, out, outl, plaintext, #plaintext)
    if ret ~= 1 then
        C.EVP_CIPHER_CTX_free(ctx)
        return nil, "EncryptUpdate failed"
    end

    local encrypted_len = outl[0]

    -- Finalize (adds PKCS7 padding)
    local final_out = ffi.new("uint8_t[32]")
    local final_l = ffi.new("int[1]", 0)
    ret = C.EVP_EncryptFinal_ex(ctx, final_out, final_l)
    C.EVP_CIPHER_CTX_free(ctx)

    if ret ~= 1 then
        return nil, "EncryptFinal failed"
    end

    -- Combine output
    local result = ffi.string(out, encrypted_len) .. ffi.string(final_out, final_l[0])
    return mime.b64(result)
end

--- Decrypt ciphertext using Rijndael-256 CBC.
--- Returns decrypted plaintext.
---@param ciphertext_b64 string base64-encoded ciphertext
---@param key string 32-byte key
---@param iv string 32-byte IV
---@return string? plaintext
---@return string? error
local function decrypt(ciphertext_b64, key, iv)
    local ciphertext = mime.unb64(ciphertext_b64)
    if not ciphertext then return nil, "invalid base64" end

    local ctx = C.EVP_CIPHER_CTX_new()
    if not ctx then return nil, "failed to create cipher context" end

    local ret = C.EVP_DecryptInit_ex(ctx, C.EVP_aes_256_cbc(), nil, key, iv)
    if ret ~= 1 then
        C.EVP_CIPHER_CTX_free(ctx)
        return nil, "DecryptInit failed"
    end

    local out = ffi.new("uint8_t[?]", #ciphertext + 32)
    local outl = ffi.new("int[1]", 0)

    ret = C.EVP_DecryptUpdate(ctx, out, outl, ciphertext, #ciphertext)
    if ret ~= 1 then
        C.EVP_CIPHER_CTX_free(ctx)
        return nil, "DecryptUpdate failed"
    end

    local decrypted_len = outl[0]

    -- Finalize (removes PKCS7 padding)
    local final_out = ffi.new("uint8_t[32]")
    local final_l = ffi.new("int[1]", 0)
    ret = C.EVP_DecryptFinal_ex(ctx, final_out, final_l)
    C.EVP_CIPHER_CTX_free(ctx)

    if ret ~= 1 then
        return nil, "DecryptFinal failed (bad padding or key/iv)"
    end

    -- Combine output
    local result = ffi.string(out, decrypted_len) .. ffi.string(final_out, final_l[0])
    return result
end

--- Derive the encryption key from osu version.
--- Key format: "osu!-scoreburgr---------{version}" (32 bytes total).
---@param osu_version string osu! client version (e.g. "20240101")
---@return string key
local function deriveKey(osu_version)
    local prefix = "osu!-scoreburgr---------"
    return prefix .. osu_version
end

return {
    encrypt = encrypt,
    decrypt = decrypt,
    deriveKey = deriveKey,
}
