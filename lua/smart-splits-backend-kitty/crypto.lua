---Kitty remote-control encryption in pure Lua for use when a password is provided.
---Commands are encrypted with AES-256-GCM under SHA-256(X25519(client private key, kitty public key)).
---See https://sw.kovidgoyal.net/kitty/rc_protocol/#encrypted-communication

local bit = require('bit')
local band, bor, bxor, bnot = bit.band, bit.bor, bit.bxor, bit.bnot
local lshift, rshift, arshift, ror, tobit = bit.lshift, bit.rshift, bit.arshift, bit.ror, bit.tobit
local floor = math.floor
local unpack = unpack

local M = {}

-- Base85 (RFC 1924 alphabet, as Python's base64.b85encode)

local B85_ALPHABET = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~'
local B85_CHARS = {}
local B85_DEC = {}
for i = 1, #B85_ALPHABET do
  B85_CHARS[i - 1] = B85_ALPHABET:sub(i, i)
  B85_DEC[B85_ALPHABET:byte(i)] = i - 1
end

---@param b string
---@return string
function M.b85encode(b)
  local padding = -#b % 4
  if padding > 0 then
    b = b .. string.rep('\0', padding)
  end
  local chunks = {}
  for i = 1, #b, 4 do
    local b0, b1, b2, b3 = b:byte(i, i + 3)
    local word = b0 * 16777216 + b1 * 65536 + b2 * 256 + b3
    local d4 = word % 85
    word = floor(word / 85)
    local d3 = word % 85
    word = floor(word / 85)
    local d2 = word % 85
    word = floor(word / 85)
    local d1 = word % 85
    local d0 = floor(word / 85)
    chunks[#chunks + 1] = B85_CHARS[d0] .. B85_CHARS[d1] .. B85_CHARS[d2] .. B85_CHARS[d3] .. B85_CHARS[d4]
  end
  local res = table.concat(chunks)
  if padding > 0 then
    res = res:sub(1, #res - padding)
  end
  return res
end

---@param s string
---@return string
function M.b85decode(s)
  local padding = -#s % 5
  if padding > 0 then
    s = s .. string.rep('~', padding)
  end
  local out = {}
  for i = 1, #s, 5 do
    local c0, c1, c2, c3, c4 = s:byte(i, i + 4)
    local d0, d1, d2, d3, d4 = B85_DEC[c0], B85_DEC[c1], B85_DEC[c2], B85_DEC[c3], B85_DEC[c4]
    if not (d0 and d1 and d2 and d3 and d4) then
      error('invalid base85 character')
    end
    local acc = (((d0 * 85 + d1) * 85 + d2) * 85 + d3) * 85 + d4
    if acc > 4294967295 then
      error('base85 overflow')
    end
    out[#out + 1] =
      string.char(floor(acc / 16777216) % 256, floor(acc / 65536) % 256, floor(acc / 256) % 256, acc % 256)
  end
  local res = table.concat(out)
  if padding > 0 then
    res = res:sub(1, #res - padding)
  end
  return res
end

-- SHA-256

-- stylua: ignore
local SHA256_K = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

---@param n integer
---@return string
local function u32_be(n)
  return string.char(band(rshift(n, 24), 255), band(rshift(n, 16), 255), band(rshift(n, 8), 255), band(n, 255))
end

---@param msg string
---@return string 32-byte digest
function M.sha256(msg)
  local bits = #msg * 8
  msg = msg
    .. '\128'
    .. string.rep('\0', (55 - #msg) % 64)
    .. u32_be(floor(bits / 4294967296))
    .. u32_be(bits % 4294967296)

  local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
  local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  local w = {}
  for chunk = 1, #msg, 64 do
    for i = 0, 15 do
      local b0, b1, b2, b3 = msg:byte(chunk + i * 4, chunk + i * 4 + 3)
      w[i] = bor(lshift(b0, 24), lshift(b1, 16), lshift(b2, 8), b3)
    end
    for i = 16, 63 do
      local x, y = w[i - 15], w[i - 2]
      local s0 = bxor(ror(x, 7), ror(x, 18), rshift(x, 3))
      local s1 = bxor(ror(y, 17), ror(y, 19), rshift(y, 10))
      w[i] = tobit(w[i - 16] + s0 + w[i - 7] + s1)
    end
    local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
    for i = 0, 63 do
      local s1 = bxor(ror(e, 6), ror(e, 11), ror(e, 25))
      local ch = bxor(band(e, f), band(bnot(e), g))
      local t1 = h + s1 + ch + SHA256_K[i + 1] + w[i]
      local s0 = bxor(ror(a, 2), ror(a, 13), ror(a, 22))
      local maj = bxor(band(a, b), band(a, c), band(b, c))
      h, g, f, e, d, c, b, a = g, f, e, tobit(d + t1), c, b, a, tobit(t1 + s0 + maj)
    end
    h0, h1, h2, h3 = tobit(h0 + a), tobit(h1 + b), tobit(h2 + c), tobit(h3 + d)
    h4, h5, h6, h7 = tobit(h4 + e), tobit(h5 + f), tobit(h6 + g), tobit(h7 + h)
  end
  return u32_be(h0) .. u32_be(h1) .. u32_be(h2) .. u32_be(h3) .. u32_be(h4) .. u32_be(h5) .. u32_be(h6) .. u32_be(h7)
end

-- AES-256, encryption direction only: GCM never needs the inverse cipher.

local SBOX, XTIME = {}, {}
do
  for i = 0, 255 do
    XTIME[i] = band(bxor(lshift(i, 1), band(i, 0x80) ~= 0 and 0x1b or 0), 0xff)
  end
  local function rotl8(x, s)
    return band(bor(lshift(x, s), rshift(x, 8 - s)), 0xff)
  end
  -- p walks the multiplicative group by 3 and q by its inverse, so q = p^-1.
  local p, q = 1, 1
  repeat
    p = bxor(p, XTIME[p])
    q = bxor(q, lshift(q, 1))
    q = bxor(q, lshift(q, 2))
    q = bxor(q, lshift(q, 4))
    q = band(q, 0xff)
    if band(q, 0x80) ~= 0 then
      q = bxor(q, 0x09)
    end
    SBOX[p] = bxor(q, rotl8(q, 1), rotl8(q, 2), rotl8(q, 3), rotl8(q, 4), 0x63)
  until p == 1
  SBOX[0] = 0x63
end

---@param key string 32 bytes
---@return integer[] 240 round-key bytes, 0-based
local function aes_expand_key(key)
  local w = {}
  for i = 0, 31 do
    w[i] = key:byte(i + 1)
  end
  local rcon = 1
  for i = 8, 59 do
    local t0, t1, t2, t3 = w[i * 4 - 4], w[i * 4 - 3], w[i * 4 - 2], w[i * 4 - 1]
    if i % 8 == 0 then
      t0, t1, t2, t3 = bxor(SBOX[t1], rcon), SBOX[t2], SBOX[t3], SBOX[t0]
      rcon = XTIME[rcon]
    elseif i % 8 == 4 then
      t0, t1, t2, t3 = SBOX[t0], SBOX[t1], SBOX[t2], SBOX[t3]
    end
    w[i * 4] = bxor(w[i * 4 - 32], t0)
    w[i * 4 + 1] = bxor(w[i * 4 - 31], t1)
    w[i * 4 + 2] = bxor(w[i * 4 - 30], t2)
    w[i * 4 + 3] = bxor(w[i * 4 - 29], t3)
  end
  return w
end

---@param rk integer[]
---@param input integer[] 16 bytes, 0-based
---@return integer[] 16 bytes, 0-based
local function aes_encrypt_block(rk, input)
  local s, t = {}, {}
  for i = 0, 15 do
    s[i] = bxor(input[i], rk[i])
  end
  for round = 1, 14 do
    -- SubBytes and ShiftRows. The state is column-major; row r rotates left by r.
    for c = 0, 3 do
      for r = 0, 3 do
        t[r + 4 * c] = SBOX[s[r + 4 * ((c + r) % 4)]]
      end
    end
    if round < 14 then
      for c = 0, 12, 4 do
        local a0, a1, a2, a3 = t[c], t[c + 1], t[c + 2], t[c + 3]
        local x0, x1, x2, x3 = XTIME[a0], XTIME[a1], XTIME[a2], XTIME[a3]
        s[c] = bxor(x0, x1, a1, a2, a3)
        s[c + 1] = bxor(a0, x1, x2, a2, a3)
        s[c + 2] = bxor(a0, a1, x2, x3, a3)
        s[c + 3] = bxor(x0, a0, a1, a2, x3)
      end
    else
      for i = 0, 15 do
        s[i] = t[i]
      end
    end
    local base = round * 16
    for i = 0, 15 do
      s[i] = bxor(s[i], rk[base + i])
    end
  end
  return s
end

-- AES-256-GCM (NIST SP 800-38D) with a 96-bit IV and no additional data.

---@param b integer[] 16 bytes, 0-based; missing bytes are zero
---@return integer, integer, integer, integer
local function to_words(b)
  local w = {}
  for i = 0, 3 do
    local j = i * 4
    w[i + 1] = bor(lshift(b[j] or 0, 24), lshift(b[j + 1] or 0, 16), lshift(b[j + 2] or 0, 8), b[j + 3] or 0)
  end
  return w[1], w[2], w[3], w[4]
end

---Multiply in GF(2^128) with GCM's bit-reflected convention.
local function gf_mul(x0, x1, x2, x3, y0, y1, y2, y3)
  local z0, z1, z2, z3 = 0, 0, 0, 0
  local x = { x0, x1, x2, x3 }
  for i = 0, 127 do
    if band(x[floor(i / 32) + 1], lshift(1, 31 - i % 32)) ~= 0 then
      z0, z1, z2, z3 = bxor(z0, y0), bxor(z1, y1), bxor(z2, y2), bxor(z3, y3)
    end
    local lsb = band(y3, 1)
    y3 = bor(rshift(y3, 1), lshift(band(y2, 1), 31))
    y2 = bor(rshift(y2, 1), lshift(band(y1, 1), 31))
    y1 = bor(rshift(y1, 1), lshift(band(y0, 1), 31))
    y0 = rshift(y0, 1)
    if lsb ~= 0 then
      y0 = bxor(y0, 0xe1000000)
    end
  end
  return z0, z1, z2, z3
end

---@param key string 32 bytes
---@param iv string 12 bytes
---@param input string
---@param encrypting boolean
---@return string output
---@return string tag 16 bytes, computed over the ciphertext
local function gcm(key, iv, input, encrypting)
  if #key ~= 32 then
    error('AES-256-GCM key must be 32 bytes')
  end
  if #iv ~= 12 then
    error('AES-GCM IV must be 12 bytes')
  end
  local rk = aes_expand_key(key)
  local zero = {}
  for i = 0, 15 do
    zero[i] = 0
  end
  local h0, h1, h2, h3 = to_words(aes_encrypt_block(rk, zero))

  local counter = {}
  for i = 0, 11 do
    counter[i] = iv:byte(i + 1)
  end
  counter[12], counter[13], counter[14], counter[15] = 0, 0, 0, 1
  local tag_mask = aes_encrypt_block(rk, counter)

  local out = {}
  local g0, g1, g2, g3 = 0, 0, 0, 0
  local n = #input
  for offset = 0, n - 1, 16 do
    for i = 15, 12, -1 do
      counter[i] = (counter[i] + 1) % 256
      if counter[i] ~= 0 then
        break
      end
    end
    local stream = aes_encrypt_block(rk, counter)
    local cipher_block, out_bytes = {}, {}
    for i = 0, math.min(15, n - offset - 1) do
      local byte = input:byte(offset + i + 1)
      local mixed = bxor(byte, stream[i])
      out_bytes[i + 1] = mixed
      cipher_block[i] = encrypting and mixed or byte
    end
    out[#out + 1] = string.char(unpack(out_bytes))
    local c0, c1, c2, c3 = to_words(cipher_block)
    g0, g1, g2, g3 = gf_mul(bxor(g0, c0), bxor(g1, c1), bxor(g2, c2), bxor(g3, c3), h0, h1, h2, h3)
  end

  local bits = n * 8
  g0, g1, g2, g3 =
    gf_mul(g0, g1, bxor(g2, floor(bits / 4294967296)), bxor(g3, tobit(bits % 4294967296)), h0, h1, h2, h3)
  local m0, m1, m2, m3 = to_words(tag_mask)
  local tag = u32_be(bxor(g0, m0)) .. u32_be(bxor(g1, m1)) .. u32_be(bxor(g2, m2)) .. u32_be(bxor(g3, m3))
  return table.concat(out), tag
end

---@param key string
---@param iv string
---@param plaintext string
---@return string ciphertext
---@return string tag
function M.aes_gcm_encrypt(key, iv, plaintext)
  return gcm(key, iv, plaintext, true)
end

---@param key string
---@param iv string
---@param ciphertext string
---@param tag string
---@return string plaintext
function M.aes_gcm_decrypt(key, iv, ciphertext, tag)
  local plaintext, expected = gcm(key, iv, ciphertext, false)
  local diff = #tag == 16 and 0 or 1
  for i = 1, 16 do
    diff = bor(diff, bxor(expected:byte(i), tag:byte(i) or 0))
  end
  if diff ~= 0 then
    error('failed to authenticate AEAD tag')
  end
  return plaintext
end

-- X25519 (RFC 7748). Field elements mod 2^255 - 19 are 16 limbs of 16 bits, ported from TweetNaCl.
-- Lua numbers are doubles, exact up to 2^53, which covers every intermediate product sum here.

local function fe(init)
  local o = {}
  for i = 0, 15 do
    o[i] = init and init[i + 1] or 0
  end
  return o
end

local FE_121665 = fe({ 0xDB41, 1 })

local function car25519(o)
  for i = 0, 15 do
    o[i] = o[i] + 65536
    local c = floor(o[i] / 65536)
    if i < 15 then
      o[i + 1] = o[i + 1] + c - 1
    else
      o[0] = o[0] + 38 * (c - 1)
    end
    o[i] = o[i] - c * 65536
  end
end

local function sel25519(p, q, b)
  if b ~= 0 then
    for i = 0, 15 do
      p[i], q[i] = q[i], p[i]
    end
  end
end

local function fe_add(o, a, b)
  for i = 0, 15 do
    o[i] = a[i] + b[i]
  end
end

local function fe_sub(o, a, b)
  for i = 0, 15 do
    o[i] = a[i] - b[i]
  end
end

local function fe_mul(o, a, b)
  local t = {}
  for i = 0, 30 do
    t[i] = 0
  end
  for i = 0, 15 do
    local ai = a[i]
    for j = 0, 15 do
      t[i + j] = t[i + j] + ai * b[j]
    end
  end
  for i = 0, 14 do
    t[i] = t[i] + 38 * t[i + 16]
  end
  for i = 0, 15 do
    o[i] = t[i]
  end
  car25519(o)
  car25519(o)
end

local function fe_inv(o, i)
  local c = fe()
  for a = 0, 15 do
    c[a] = i[a]
  end
  for a = 253, 0, -1 do
    fe_mul(c, c, c)
    if a ~= 2 and a ~= 4 then
      fe_mul(c, c, i)
    end
  end
  for a = 0, 15 do
    o[a] = c[a]
  end
end

---@param n table field element
---@return string 32 bytes, little-endian
local function pack25519(n)
  local t, m = fe(), fe()
  for i = 0, 15 do
    t[i] = n[i]
  end
  car25519(t)
  car25519(t)
  car25519(t)
  for _ = 1, 2 do
    m[0] = t[0] - 0xffed
    for i = 1, 14 do
      m[i] = t[i] - 0xffff - band(arshift(m[i - 1], 16), 1)
      m[i - 1] = band(m[i - 1], 0xffff)
    end
    m[15] = t[15] - 0x7fff - band(arshift(m[14], 16), 1)
    local b = band(arshift(m[15], 16), 1)
    m[14] = band(m[14], 0xffff)
    sel25519(t, m, 1 - b)
  end
  local out = {}
  for i = 0, 15 do
    out[2 * i + 1] = band(t[i], 0xff)
    out[2 * i + 2] = band(rshift(t[i], 8), 0xff)
  end
  return string.char(unpack(out))
end

---@param s string 32 bytes, little-endian
local function unpack25519(s)
  local o = fe()
  for i = 0, 15 do
    o[i] = s:byte(2 * i + 1) + s:byte(2 * i + 2) * 256
  end
  o[15] = band(o[15], 0x7fff)
  return o
end

---@param scalar string 32 bytes
---@param point string 32 bytes, u-coordinate
---@return string 32 bytes
function M.x25519(scalar, point)
  if #scalar ~= 32 or #point ~= 32 then
    error('X25519 inputs must be 32 bytes')
  end
  local z = { scalar:byte(1, 32) }
  z[32] = bor(band(z[32], 127), 64)
  z[1] = band(z[1], 248)

  local x = unpack25519(point)
  local a, b, c, d, e, f = fe(), fe(), fe(), fe(), fe(), fe()
  for i = 0, 15 do
    b[i] = x[i]
  end
  a[0], d[0] = 1, 1

  for i = 254, 0, -1 do
    local r = band(rshift(z[floor(i / 8) + 1], i % 8), 1)
    sel25519(a, b, r)
    sel25519(c, d, r)
    fe_add(e, a, c)
    fe_sub(a, a, c)
    fe_add(c, b, d)
    fe_sub(b, b, d)
    fe_mul(d, e, e)
    fe_mul(f, a, a)
    fe_mul(a, c, a)
    fe_mul(c, b, e)
    fe_add(e, a, c)
    fe_sub(a, a, c)
    fe_mul(b, a, a)
    fe_sub(c, d, f)
    fe_mul(a, c, FE_121665)
    fe_add(a, a, d)
    fe_mul(c, c, a)
    fe_mul(a, d, f)
    fe_mul(d, b, x)
    fe_mul(b, e, e)
    sel25519(a, b, r)
    sel25519(c, d, r)
  end
  fe_inv(c, c)
  fe_mul(a, a, c)
  return pack25519(a)
end

local BASEPOINT = string.char(9) .. string.rep('\0', 31)

---@param private? string 32 bytes; random when omitted
---@return { private: string, public: string }
function M.generate_keypair(private)
  private = private or vim.uv.random(32)
  if not private or #private ~= 32 then
    error('failed to generate random bytes for X25519 key')
  end
  return { private = private, public = M.x25519(private, BASEPOINT) }
end

-- Kitty protocol

---X25519 dominates the cost, so the client key and derived AES key live for the
---session and are only recomputed when kitty's public key changes.
---@type { peer: string, public: string, key: string }|nil
local session = nil

---@param peer_pubkey string 32 bytes
---@return string aes_key
---@return string client_pubkey
local function session_key(peer_pubkey)
  if not session or session.peer ~= peer_pubkey then
    local pair = M.generate_keypair()
    session = {
      peer = peer_pubkey,
      public = pair.public,
      key = M.sha256(M.x25519(pair.private, peer_pubkey)),
    }
  end
  return session.key, session.public
end

---@return string
local function timestamp_ns()
  local t = vim.uv.clock_gettime('realtime')
  if not t then
    error('failed to get system time')
  end
  return ('%d%09d'):format(t.sec, t.nsec)
end

---@return string
local function peer_public_key()
  local raw_key = vim.env.KITTY_PUBLIC_KEY
  if type(raw_key) ~= 'string' or raw_key == '' then
    error('KITTY_PUBLIC_KEY is unset')
  end
  local proto, b85_key = raw_key:match('^(%d+):(.+)$')
  if not proto or not b85_key then
    error('invalid KITTY_PUBLIC_KEY: missing protocol or key data')
  end
  if proto ~= '1' then
    error('unsupported KITTY_PUBLIC_KEY protocol: ' .. proto)
  end
  local key = M.b85decode(b85_key)
  if #key ~= 32 then
    error('invalid KITTY_PUBLIC_KEY: decoded key length is not 32 bytes')
  end
  return key
end

---Encrypt a command if it carries a password, otherwise return it unchanged.
---@param command table
---@return table
function M.encrypt(command)
  if type(command.password) ~= 'string' or command.password == '' then
    return command
  end
  local key, client_pubkey = session_key(peer_public_key())

  local inner = vim.deepcopy(command)
  local iv = inner._iv or vim.uv.random(12)
  inner._iv = nil
  if not iv then
    error('failed to generate random bytes for IV')
  end
  -- Kitty drops a command whose timestamp is not a JSON integer, and nanoseconds exceed what a
  -- Lua number encodes exactly, so the digits are spliced in after encoding.
  local placeholder = '__smart_splits_timestamp__'
  inner.timestamp = placeholder
  local plaintext = vim.json.encode(inner):gsub('"' .. placeholder .. '"', timestamp_ns(), 1)

  local ciphertext, tag = M.aes_gcm_encrypt(key, iv, plaintext)
  return {
    version = command.version,
    iv = M.b85encode(iv),
    tag = M.b85encode(tag),
    pubkey = M.b85encode(client_pubkey),
    encrypted = M.b85encode(ciphertext),
  }
end

---Decrypt an envelope the way kitty does. Tests use it to stand in for kitty.
---@param envelope table
---@param private string kitty's raw 32-byte private key
---@return string plaintext JSON
function M.decrypt(envelope, private)
  if type(envelope) ~= 'table' or not envelope.encrypted then
    error('invalid encrypted envelope')
  end
  local key = M.sha256(M.x25519(private, M.b85decode(envelope.pubkey)))
  return M.aes_gcm_decrypt(key, M.b85decode(envelope.iv), M.b85decode(envelope.encrypted), M.b85decode(envelope.tag))
end

return M
