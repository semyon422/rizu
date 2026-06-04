--- Rijndael-256 CBC encryption/decryption for osu! score submission.
---
--- Implements the osu! score submission encryption scheme:
--- Rijndael-256 CBC with PKCS7 padding, block size 32.
---
--- Ported from py3rijndael (meyt/py3rijndael).
--- Uses pre-computed T-boxes for performance.

local bit = require("bit")
local mime = require("mime")

local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local lshift = bit.lshift
local rshift = bit.rshift

--- Mask to 32-bit unsigned.
--- band(v, 0xFFFFFFFF) doesn't work in LuaJIT for sign extension.
--- Use modulo instead.
local function u32(v)
    return v % 0x100000000
end

local M = {}

--- Generate log and a_log tables for GF(2^8) multiplication.
local function generate_log_tables()
    -- a_log is 0-indexed: a_log[0] = 1, a_log[1] = 3, etc.
    local a_log = {}
    a_log[0] = 1
    for _ = 1, 255 do
        local j = bxor(lshift(a_log[#a_log], 1), a_log[#a_log])
        if band(j, 0x100) ~= 0 then
            j = bxor(j, 0x11B)
        end
        table.insert(a_log, j)
    end

    local log = {}
    for i = 0, 255 do
        log[i] = 0
    end
    for i = 1, 254 do
        log[a_log[i]] = i
    end
    return a_log, log
end

--- Multiply two elements of GF(2^8).
local function mul(a, b, a_log, log)
    if a == 0 or b == 0 then
        return 0
    end
    return a_log[(log[band(a, 0xFF)] + log[band(b, 0xFF)]) % 255]
end

--- Generate S-box and inverse S-box.
local function generate_sbox(a_log, log)
    -- Multiplication matrix A
    local A = {
        { 1, 1, 1, 1, 1, 0, 0, 0 },
        { 0, 1, 1, 1, 1, 1, 0, 0 },
        { 0, 0, 1, 1, 1, 1, 1, 0 },
        { 0, 0, 0, 1, 1, 1, 1, 1 },
        { 1, 0, 0, 0, 1, 1, 1, 1 },
        { 1, 1, 0, 0, 0, 1, 1, 1 },
        { 1, 1, 1, 0, 0, 0, 1, 1 },
        { 1, 1, 1, 1, 0, 0, 0, 1 },
    }

    -- Inverse in GF(2^8)
    local box = {}
    box[1] = { 0, 0, 0, 0, 0, 0, 0, 1 }
    for i = 2, 255 do
        local j = a_log[255 - log[i]]
        local bits = {}
        for t = 0, 7 do
            bits[t + 1] = band(rshift(j, 7 - t), 0x01)
        end
        box[i] = bits
    end

    -- Affine transform: cox[i] = B + A * box[i]
    local B = { 0, 1, 1, 0, 0, 0, 1, 1 }
    local cox = {}
    for i = 0, 255 do
        local row = {}
        for t = 0, 7 do
            local val = B[t + 1]
            for j = 0, 7 do
                val = bxor(val, A[t + 1][j + 1] * (box[i] and box[i][j + 1] or 0))
            end
            row[t + 1] = val
        end
        cox[i] = row
    end

    -- Build S and Si
    local S = {}
    local Si = {}
    for i = 0, 255 do
        local val = 0
        for t = 0, 7 do
            val = bor(val, lshift(cox[i][t + 1], 7 - t))
        end
        S[i] = band(val, 0xFF)
        Si[band(val, 0xFF)] = i
    end

    return S, Si
end

--- Multiply byte by vector in GF(2^8).
local function mul4(a, bs, a_log, log)
    if a == 0 then
        return 0
    end
    local rr = 0
    for _, b in ipairs(bs) do
        rr = lshift(rr, 8)
        if b ~= 0 then
            rr = bor(rr, mul(a, b, a_log, log))
        end
    end
    return u32(rr) -- Mask to 32 bits unsigned
end

--- Generate T-boxes for encryption and decryption.
local function generate_tboxes(S, Si, a_log, log)
    -- G matrix (MixColumns)
    local G = {
        { 2, 1, 1, 3 },
        { 3, 2, 1, 1 },
        { 1, 3, 2, 1 },
        { 1, 1, 3, 2 },
    }

    -- Inverse G matrix (using Gaussian elimination)
    local AA = {}
    for i = 1, 4 do
        AA[i] = {}
        for j = 1, 4 do
            AA[i][j] = G[i][j]
        end
        for j = 5, 8 do
            AA[i][j] = (j == 4 + i) and 1 or 0
        end
    end

    -- Gaussian elimination
    for i = 1, 4 do
        local pivot = AA[i][i]
        for j = 1, 8 do
            if AA[i][j] ~= 0 then
                AA[i][j] = a_log[(255 + log[band(AA[i][j], 0xFF)] - log[band(pivot, 0xFF)]) % 255]
            end
        end
        for t = 1, 4 do
            if i ~= t then
                for j = i + 1, 8 do
                    AA[t][j] = bxor(AA[t][j], mul(AA[i][j], AA[t][i], a_log, log))
                end
                AA[t][i] = 0
            end
        end
    end

    local iG = {}
    for i = 1, 4 do
        iG[i] = {}
        for j = 1, 4 do
            iG[i][j] = AA[i][j + 4]
        end
    end

    -- T1-T4 for encryption, T5-T8 for decryption
    local T1, T2, T3, T4 = {}, {}, {}, {}
    local T5, T6, T7, T8 = {}, {}, {}, {}
    local U1, U2, U3, U4 = {}, {}, {}, {}

    for t = 0, 255 do
        local s = S[t]
        T1[t] = mul4(s, G[1], a_log, log)
        T2[t] = mul4(s, G[2], a_log, log)
        T3[t] = mul4(s, G[3], a_log, log)
        T4[t] = mul4(s, G[4], a_log, log)

        local si = Si[t]
        T5[t] = mul4(si, iG[1], a_log, log)
        T6[t] = mul4(si, iG[2], a_log, log)
        T7[t] = mul4(si, iG[3], a_log, log)
        T8[t] = mul4(si, iG[4], a_log, log)

        U1[t] = mul4(t, iG[1], a_log, log)
        U2[t] = mul4(t, iG[2], a_log, log)
        U3[t] = mul4(t, iG[3], a_log, log)
        U4[t] = mul4(t, iG[4], a_log, log)
    end

    return T1, T2, T3, T4, T5, T6, T7, T8, U1, U2, U3, U4
end

--- Generate round constants.
local function generate_round_constants(a_log, log)
    local r_con = { 1 }
    local r = 1
    for _ = 1, 30 do
        r = mul(2, r, a_log, log)
        table.insert(r_con, r)
    end
    return r_con
end

--- Generate all Rijndael tables.
local function init()
    local a_log, log = generate_log_tables()
    local S, Si = generate_sbox(a_log, log)
    local T1, T2, T3, T4, T5, T6, T7, T8, U1, U2, U3, U4 =
        generate_tboxes(S, Si, a_log, log)
    local r_con = generate_round_constants(a_log, log)

    return {
        S = S,
        Si = Si,
        T1 = T1,
        T2 = T2,
        T3 = T3,
        T4 = T4,
        T5 = T5,
        T6 = T6,
        T7 = T7,
        T8 = T8,
        U1 = U1,
        U2 = U2,
        U3 = U3,
        U4 = U4,
        r_con = r_con,
    }
end

-- Pre-compute all tables
local tables = init()

-- Shifts for different block sizes
-- [block_size_index][shift_row][encrypt=1/decrypt=2]
-- block_size_index: 1=16, 2=24, 3=32
-- shift_row: 1=s1, 2=s2, 3=s3
-- Python: shifts[s_c][row][0] = encrypt, shifts[s_c][row][1] = decrypt
local shifts = {
    -- block_size=16 (b_c=4): s1=1/3, s2=2/2, s3=3/1
    { { 1, 3 }, { 2, 2 }, { 3, 1 } },
    -- block_size=24 (b_c=6): s1=1/5, s2=2/4, s3=3/3
    { { 1, 5 }, { 2, 4 }, { 3, 3 } },
    -- block_size=32 (b_c=8): s1=1/7, s2=3/5, s3=4/4
    { { 1, 7 }, { 3, 5 }, { 4, 4 } },
}

-- Number of rounds: [key_size][block_size]
local num_rounds = {
    [16] = { [16] = 10, [24] = 12, [32] = 14 },
    [24] = { [16] = 12, [24] = 12, [32] = 14 },
    [32] = { [16] = 14, [24] = 14, [32] = 14 },
}

--- Rijndael cipher core.
local Rijndael = {}
Rijndael.__index = Rijndael

--- Create a new Rijndael cipher.
---@param key string key (16, 24, or 32 bytes)
---@param block_size integer block size (16, 24, or 32 bytes)
function Rijndael.new(key, block_size)
    if block_size ~= 16 and block_size ~= 24 and block_size ~= 32 then
        error("Invalid block size: " .. block_size)
    end
    if #key ~= 16 and #key ~= 24 and #key ~= 32 then
        error("Invalid key size: " .. #key)
    end

    local self = setmetatable({}, Rijndael)
    self.block_size = block_size
    self.key = key

    local rounds = num_rounds[#key][block_size]
    local b_c = math.floor(block_size / 4) -- number of 32-bit words per block
    local k_c = math.floor(#key / 4) -- number of 32-bit words per key

    -- Initialize round key arrays
    local k_e = {} -- encryption keys
    local k_d = {} -- decryption keys
    for i = 0, rounds do
        k_e[i] = {}
        k_d[i] = {}
        for j = 0, b_c - 1 do
            k_e[i][j] = 0
            k_d[i][j] = 0
        end
    end

    -- Copy key material to 32-bit words
    local tk = {}
    for i = 0, k_c - 1 do
        tk[i] = u32(bor(bor(bor(
            lshift(key:byte(i * 4 + 1, i * 4 + 1), 24),
            lshift(key:byte(i * 4 + 2, i * 4 + 2), 16)),
            lshift(key:byte(i * 4 + 3, i * 4 + 3), 8)),
            key:byte(i * 4 + 4, i * 4 + 4)))
    end

    -- Copy values into round key arrays
    local t = 0
    local j = 0
    while j < k_c and t < (rounds + 1) * b_c do
        k_e[math.floor(t / b_c)][t % b_c] = tk[j]
        k_d[rounds - math.floor(t / b_c)][t % b_c] = tk[j]
        j = j + 1
        t = t + 1
    end

    -- Key schedule
    local r_con_pointer = 1
    while t < (rounds + 1) * b_c do
        local tt = tk[k_c - 1]

        -- Phi function
        tk[0] = u32(bxor(tk[0],
            bxor(bxor(
                lshift(tables.S[band(rshift(tt, 16), 0xFF)], 24),
                lshift(tables.S[band(rshift(tt, 8), 0xFF)], 16)),
                bxor(
                    lshift(tables.S[band(tt, 0xFF)], 8),
                    bxor(
                        tables.S[band(rshift(tt, 24), 0xFF)],
                        lshift(tables.r_con[r_con_pointer], 24))))))
        r_con_pointer = r_con_pointer + 1

        if k_c ~= 8 then
            for i = 1, k_c - 1 do
                tk[i] = u32(bxor(tk[i], tk[i - 1]))
            end
        else
            for i = 1, math.floor(k_c / 2) - 1 do
                tk[i] = u32(bxor(tk[i], tk[i - 1]))
            end
            tt = tk[math.floor(k_c / 2) - 1]
            tk[math.floor(k_c / 2)] = u32(bxor(
                tk[math.floor(k_c / 2)],
                bxor(
                    bxor(
                        tables.S[band(tt, 0xFF)],
                        lshift(tables.S[band(rshift(tt, 8), 0xFF)], 8)
                    ),
                    bxor(
                        lshift(tables.S[band(rshift(tt, 16), 0xFF)], 16),
                        lshift(tables.S[band(rshift(tt, 24), 0xFF)], 24)
                    )
                ))
            )
            for i = math.floor(k_c / 2) + 1, k_c - 1 do
                tk[i] = u32(bxor(tk[i], tk[i - 1]))
            end
        end

        -- Copy values into round key arrays
        j = 0
        while j < k_c and t < (rounds + 1) * b_c do
            k_e[math.floor(t / b_c)][t % b_c] = tk[j]
            k_d[rounds - math.floor(t / b_c)][t % b_c] = tk[j]
            j = j + 1
            t = t + 1
        end
    end

    -- Inverse MixColumns for decryption keys
    for r = 1, rounds - 1 do
        for col = 0, b_c - 1 do
            local tt = k_d[r][col]
            k_d[r][col] = u32(bxor(bxor(
                tables.U1[band(rshift(tt, 24), 0xFF)],
                tables.U2[band(rshift(tt, 16), 0xFF)]),
                bxor(
                    tables.U3[band(rshift(tt, 8), 0xFF)],
                    tables.U4[band(tt, 0xFF)])))
        end
    end

    self.Ke = k_e
    self.Kd = k_d
    self.rounds = rounds
    return self
end

--- Encrypt a single block.
---@param source string plaintext block (must be block_size bytes)
---@return string ciphertext block
function Rijndael:encrypt(source)
    if #source ~= self.block_size then
        error("Wrong block length, expected " .. self.block_size .. " got " .. #source)
    end

    local k_e = self.Ke
    local b_c = math.floor(self.block_size / 4)
    local rounds = self.rounds

    -- Determine shift configuration
    local s_c = (b_c == 4) and 1 or (b_c == 6) and 2 or 3
    local s1 = shifts[s_c][1][1] -- encrypt shifts
    local s2 = shifts[s_c][2][1]
    local s3 = shifts[s_c][3][1]

    -- Source to 32-bit words + initial key addition
    local t = {}
    for i = 0, b_c - 1 do
        t[i] = u32(bxor(
            bor(bor(
                lshift(source:byte(i * 4 + 1, i * 4 + 1), 24),
                lshift(source:byte(i * 4 + 2, i * 4 + 2), 16)),
                bor(
                    lshift(source:byte(i * 4 + 3, i * 4 + 3), 8),
                    source:byte(i * 4 + 4, i * 4 + 4))),
            k_e[0][i]))
    end

    -- Apply round transforms
    for r = 1, rounds - 1 do
        local a = {}
        for i = 0, b_c - 1 do
            a[i] = u32(bxor(bxor(bxor(
                tables.T1[band(rshift(t[i], 24), 0xFF)],
                tables.T2[band(rshift(t[(i + s1) % b_c], 16), 0xFF)]),
                bxor(
                    tables.T3[band(rshift(t[(i + s2) % b_c], 8), 0xFF)],
                    tables.T4[band(t[(i + s3) % b_c], 0xFF)])),
                k_e[r][i]))
        end
        t = a

    end

    -- Last round
    local result = {}
    for i = 0, b_c - 1 do
        local tt = k_e[rounds][i]
        result[#result + 1] = band(bxor(tables.S[band(rshift(t[i], 24), 0xFF)], rshift(tt, 24)), 0xFF)
        result[#result + 1] = band(bxor(tables.S[band(rshift(t[(i + s1) % b_c], 16), 0xFF)], rshift(tt, 16)), 0xFF)
        result[#result + 1] = band(bxor(tables.S[band(rshift(t[(i + s2) % b_c], 8), 0xFF)], rshift(tt, 8)), 0xFF)
        result[#result + 1] = band(bxor(tables.S[band(t[(i + s3) % b_c], 0xFF)], tt), 0xFF)
    end

    return string.char(unpack(result))
end

--- Decrypt a single block.
---@param cipher string ciphertext block (must be block_size bytes)
---@return string plaintext block
function Rijndael:decrypt(cipher)
    if #cipher ~= self.block_size then
        error("Wrong block length, expected " .. self.block_size .. " got " .. #cipher)
    end

    local k_d = self.Kd
    local b_c = math.floor(self.block_size / 4)
    local rounds = self.rounds

    -- Determine shift configuration
    local s_c = (b_c == 4) and 1 or (b_c == 6) and 2 or 3
    local s1 = shifts[s_c][1][2] -- decrypt shifts
    local s2 = shifts[s_c][2][2]
    local s3 = shifts[s_c][3][2]

    -- Cipher to 32-bit words + initial key addition
    local t = {}
    for i = 0, b_c - 1 do
        t[i] = u32(bxor(
            bor(bor(
                lshift(cipher:byte(i * 4 + 1, i * 4 + 1), 24),
                lshift(cipher:byte(i * 4 + 2, i * 4 + 2), 16)),
                bor(
                    lshift(cipher:byte(i * 4 + 3, i * 4 + 3), 8),
                    cipher:byte(i * 4 + 4, i * 4 + 4))),
            k_d[0][i]))
    end

    -- Apply round transforms
    for r = 1, rounds - 1 do
        local a = {}
        for i = 0, b_c - 1 do
            a[i] = u32(bxor(bxor(bxor(
                tables.T5[band(rshift(t[i], 24), 0xFF)],
                tables.T6[band(rshift(t[(i + s1) % b_c], 16), 0xFF)]),
                bxor(
                    tables.T7[band(rshift(t[(i + s2) % b_c], 8), 0xFF)],
                    tables.T8[band(t[(i + s3) % b_c], 0xFF)])),
                k_d[r][i]))
        end
        t = a
    end

    -- Last round
    local result = {}
    for i = 0, b_c - 1 do
        local tt = k_d[rounds][i]
        result[#result + 1] = band(bxor(tables.Si[band(rshift(t[i], 24), 0xFF)], rshift(tt, 24)), 0xFF)
        result[#result + 1] = band(bxor(tables.Si[band(rshift(t[(i + s1) % b_c], 16), 0xFF)], rshift(tt, 16)), 0xFF)
        result[#result + 1] = band(bxor(tables.Si[band(rshift(t[(i + s2) % b_c], 8), 0xFF)], rshift(tt, 8)), 0xFF)
        result[#result + 1] = band(bxor(tables.Si[band(t[(i + s3) % b_c], 0xFF)], tt), 0xFF)
    end

    return string.char(unpack(result))
end

--- XOR two blocks together.
local function xor_block(b1, b2)
    local result = {}
    for i = 1, #b1 do
        result[i] = bxor(b1:byte(i), b2:byte(i))
    end
    return string.char(unpack(result))
end

--- PKCS7 padding.
local function pkcs7_pad(data, block_size)
    local pad_len = block_size - (#data % block_size)
    return data .. string.rep(string.char(pad_len), pad_len)
end

--- Remove PKCS7 padding.
local function pkcs7_unpad(data)
    local pad_len = data:byte(#data)
    return data:sub(1, #data - pad_len)
end

--- Rijndael CBC mode.
local RijndaelCbc = {}
RijndaelCbc.__index = RijndaelCbc

--- Create a new Rijndael CBC cipher.
---@param key string key (16, 24, or 32 bytes)
---@param iv string initialization vector (must be block_size bytes)
---@param block_size integer block size (16, 24, or 32 bytes)
function RijndaelCbc.new(key, iv, block_size)
    local self = setmetatable({}, RijndaelCbc)
    self.cipher = Rijndael.new(key, block_size)
    self.iv = iv
    self.block_size = block_size
    return self
end

--- Encrypt data with CBC mode and PKCS7 padding.
---@param plaintext string
---@return string ciphertext
function RijndaelCbc:encrypt(plaintext)
    local padded = pkcs7_pad(plaintext, self.block_size)
    local ct = {}
    local prev = self.iv

    for offset = 1, #padded, self.block_size do
        local block = padded:sub(offset, offset + self.block_size - 1)
        local xored = xor_block(block, prev)
        local encrypted = self.cipher:encrypt(xored)
        ct[#ct + 1] = encrypted
        prev = encrypted
    end

    return table.concat(ct)
end

--- Decrypt data with CBC mode and PKCS7 padding.
---@param ciphertext string
---@return string plaintext
function RijndaelCbc:decrypt(ciphertext)
    if #ciphertext % self.block_size ~= 0 then
        error("Ciphertext length must be multiple of block size")
    end

    local ppt = {}
    local prev = self.iv

    for offset = 1, #ciphertext, self.block_size do
        local block = ciphertext:sub(offset, offset + self.block_size - 1)
        local decrypted = self.cipher:decrypt(block)
        ppt[#ppt + 1] = xor_block(decrypted, prev)
        prev = block
    end

    return pkcs7_unpad(table.concat(ppt))
end

--- Derive the encryption key from osu version.
--- Key format: "osu!-scoreburgr---------{version}" (32 bytes total).
---@param osu_version string osu! client version (e.g. "20240101")
---@return string key
function M.deriveKey(osu_version)
    return "osu!-scoreburgr---------" .. osu_version
end

--- Encrypt plaintext using Rijndael-256 CBC.
--- Returns base64-encoded ciphertext.
---@param plaintext string
---@param key string 32-byte key
---@param iv_b64 string base64-encoded IV (32 bytes)
---@return string? ciphertext_b64
---@return string? error
function M.encrypt(plaintext, key, iv_b64)
    local iv = mime.unb64(iv_b64)
    if not iv or #iv ~= 32 then
        return nil, "invalid IV"
    end

    local cipher = RijndaelCbc.new(key, iv, 32)
    local ciphertext = cipher:encrypt(plaintext)
    return mime.b64(ciphertext)
end

--- Decrypt ciphertext using Rijndael-256 CBC.
--- Returns decrypted plaintext with PKCS7 padding removed.
---@param ciphertext_b64 string base64-encoded ciphertext
---@param key string 32-byte key
---@param iv_b64 string base64-encoded IV (32 bytes)
---@return string? plaintext
---@return string? error
function M.decrypt(ciphertext_b64, key, iv_b64)
    local iv = mime.unb64(iv_b64)
    if not iv or #iv ~= 32 then
        return nil, "invalid IV"
    end

    local ciphertext = mime.unb64(ciphertext_b64)
    if not ciphertext then
        return nil, "invalid base64"
    end

    local cipher = RijndaelCbc.new(key, iv, 32)
    return cipher:decrypt(ciphertext)
end

M.Rijndael = Rijndael
M.RijndaelCbc = RijndaelCbc
return M
