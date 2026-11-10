---Kitty remote-control encryption and Base85 utilities.
---See https://sw.kovidgoyal.net/kitty/rc_protocol/

local ffi = require('ffi')

local M = {}

local B85_ALPHABET = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~'
local B85_CHARS = {}
local B85_DEC = {}
for i = 1, #B85_ALPHABET do
  B85_CHARS[i - 1] = B85_ALPHABET:sub(i, i)
  B85_DEC[B85_ALPHABET:byte(i)] = i - 1
end

pcall(
  ffi.cdef,
  [[
  typedef struct evp_pkey_st EVP_PKEY;
  typedef struct evp_pkey_ctx_st EVP_PKEY_CTX;
  typedef struct evp_cipher_ctx_st EVP_CIPHER_CTX;
  typedef struct evp_cipher_st EVP_CIPHER;

  int OBJ_sn2nid(const char *s);
  const EVP_CIPHER *EVP_aes_256_gcm(void);
  EVP_CIPHER_CTX *EVP_CIPHER_CTX_new(void);
  void EVP_CIPHER_CTX_free(EVP_CIPHER_CTX *ctx);
  int EVP_EncryptInit_ex(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *cipher, void *impl, const unsigned char *key, const unsigned char *iv);
  int EVP_DecryptInit_ex(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *cipher, void *impl, const unsigned char *key, const unsigned char *iv);
  int EVP_CIPHER_CTX_ctrl(EVP_CIPHER_CTX *ctx, int type, int arg, void *ptr);
  int EVP_EncryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl, const unsigned char *in, int inl);
  int EVP_EncryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl);
  int EVP_DecryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl, const unsigned char *in, int inl);
  int EVP_DecryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl);

  unsigned char *SHA256(const unsigned char *d, size_t n, unsigned char *md);

  EVP_PKEY_CTX *EVP_PKEY_CTX_new_id(int id, void *e);
  void EVP_PKEY_CTX_free(EVP_PKEY_CTX *ctx);
  int EVP_PKEY_keygen_init(EVP_PKEY_CTX *ctx);
  int EVP_PKEY_keygen(EVP_PKEY_CTX *ctx, EVP_PKEY **ppkey);
  void EVP_PKEY_free(EVP_PKEY *key);
  int EVP_PKEY_get_raw_public_key(const EVP_PKEY *pkey, unsigned char *pub, size_t *len);
  int EVP_PKEY_get_raw_private_key(const EVP_PKEY *pkey, unsigned char *priv, size_t *len);
  EVP_PKEY *EVP_PKEY_new_raw_public_key(int type, void *e, const unsigned char *key, size_t keylen);
  EVP_PKEY *EVP_PKEY_new_raw_private_key(int type, void *e, const unsigned char *key, size_t keylen);
  EVP_PKEY_CTX *EVP_PKEY_CTX_new(EVP_PKEY *pkey, void *e);
  int EVP_PKEY_derive_init(EVP_PKEY_CTX *ctx);
  int EVP_PKEY_derive_set_peer(EVP_PKEY_CTX *ctx, EVP_PKEY *peer);
  int EVP_PKEY_derive(EVP_PKEY_CTX *ctx, unsigned char *key, size_t *keylen);
]]
)

local loaded_crypto = nil
local function get_crypto()
  if loaded_crypto then
    return loaded_crypto
  end
  local names = {
    'crypto',
    'libcrypto.so.3',
    'libcrypto.so.1.1',
    'libcrypto.so',
    'libcrypto.dylib',
    '/opt/homebrew/opt/openssl@3/lib/libcrypto.dylib',
    '/usr/local/opt/openssl@3/lib/libcrypto.dylib',
    '/opt/homebrew/opt/openssl/lib/libcrypto.dylib',
    '/usr/local/opt/openssl/lib/libcrypto.dylib',
    '/usr/lib/libcrypto.dylib',
    'libcrypto-3-x64',
    'libcrypto-1_1-x64',
  }
  for _, name in ipairs(names) do
    local ok, lib = pcall(ffi.load, name)
    if ok and lib then
      loaded_crypto = lib
      return loaded_crypto
    end
  end
  local ok, lib = pcall(function()
    return ffi.C
  end)
  if ok and lib then
    loaded_crypto = lib
    return loaded_crypto
  end
  error('failed to load OpenSSL libcrypto for encrypted kitty communication')
end

local cached_nid = nil
local function get_nid_x25519(crypto)
  if cached_nid then
    return cached_nid
  end
  local ok, nid = pcall(crypto.OBJ_sn2nid, 'X25519')
  if ok and type(nid) == 'number' and nid > 0 then
    cached_nid = nid
    return cached_nid
  end
  cached_nid = 1034
  return cached_nid
end

---RFC 1924 / Python standard Base85 encoding.
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
    word = math.floor(word / 85)
    local d3 = word % 85
    word = math.floor(word / 85)
    local d2 = word % 85
    word = math.floor(word / 85)
    local d1 = word % 85
    local d0 = math.floor(word / 85)
    chunks[#chunks + 1] = B85_CHARS[d0] .. B85_CHARS[d1] .. B85_CHARS[d2] .. B85_CHARS[d3] .. B85_CHARS[d4]
  end
  local res = table.concat(chunks)
  if padding > 0 then
    res = res:sub(1, #res - padding)
  end
  return res
end

---RFC 1924 / Python standard Base85 decoding.
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
    local b0 = math.floor(acc / 16777216) % 256
    local b1 = math.floor(acc / 65536) % 256
    local b2 = math.floor(acc / 256) % 256
    local b3 = acc % 256
    out[#out + 1] = string.char(b0, b1, b2, b3)
  end
  local res = table.concat(out)
  if padding > 0 then
    res = res:sub(1, #res - padding)
  end
  return res
end

---@param peer_pubkey_raw string
---@param iv string
---@param plaintext string
---@return string ciphertext
---@return string tag
---@return string client_pubkey
function M.encrypt_payload(peer_pubkey_raw, iv, plaintext)
  local crypto = get_crypto()
  local nid = get_nid_x25519(crypto)

  local pctx = crypto.EVP_PKEY_CTX_new_id(nid, nil)
  if pctx == nil then
    error('failed to create OpenSSL keygen context')
  end
  if crypto.EVP_PKEY_keygen_init(pctx) ~= 1 then
    crypto.EVP_PKEY_CTX_free(pctx)
    error('failed to initialize keygen context')
  end
  local pkey = ffi.new('EVP_PKEY*[1]')
  if crypto.EVP_PKEY_keygen(pctx, pkey) ~= 1 or pkey[0] == nil then
    crypto.EVP_PKEY_CTX_free(pctx)
    error('failed to generate X25519 key')
  end
  crypto.EVP_PKEY_CTX_free(pctx)

  local ok, res_or_err = pcall(function()
    local publen = ffi.new('size_t[1]', 32)
    local pubbuf = ffi.new('unsigned char[32]')
    if crypto.EVP_PKEY_get_raw_public_key(pkey[0], pubbuf, publen) ~= 1 then
      error('failed to get raw public key')
    end
    local client_pubkey = ffi.string(pubbuf, publen[0])

    local peer_key = crypto.EVP_PKEY_new_raw_public_key(nid, nil, peer_pubkey_raw, #peer_pubkey_raw)
    if peer_key == nil then
      error('failed to load peer public key')
    end

    local dctx = crypto.EVP_PKEY_CTX_new(pkey[0], nil)
    if dctx == nil then
      crypto.EVP_PKEY_free(peer_key)
      error('failed to create derive context')
    end

    local sym_key = ffi.new('unsigned char[32]')
    local derive_ok, derive_err = pcall(function()
      if crypto.EVP_PKEY_derive_init(dctx) ~= 1 then
        error('failed to initialize derive context')
      end
      if crypto.EVP_PKEY_derive_set_peer(dctx, peer_key) ~= 1 then
        error('failed to set peer key')
      end
      local secret_len = ffi.new('size_t[1]', 0)
      if crypto.EVP_PKEY_derive(dctx, nil, secret_len) ~= 1 then
        error('failed to get shared secret length')
      end
      local secret = ffi.new('unsigned char[?]', secret_len[0])
      if crypto.EVP_PKEY_derive(dctx, secret, secret_len) ~= 1 then
        error('failed to derive shared secret')
      end
      crypto.SHA256(secret, secret_len[0], sym_key)
    end)

    crypto.EVP_PKEY_CTX_free(dctx)
    crypto.EVP_PKEY_free(peer_key)
    if not derive_ok then
      error(derive_err)
    end

    local cctx = crypto.EVP_CIPHER_CTX_new()
    if cctx == nil then
      error('failed to create cipher context')
    end

    local enc_ok, enc_res = pcall(function()
      if crypto.EVP_EncryptInit_ex(cctx, crypto.EVP_aes_256_gcm(), nil, nil, nil) ~= 1 then
        error('failed to initialize AES-256-GCM cipher')
      end
      if crypto.EVP_CIPHER_CTX_ctrl(cctx, 0x9, #iv, nil) ~= 1 then
        error('failed to set IV length')
      end
      if crypto.EVP_EncryptInit_ex(cctx, nil, nil, sym_key, iv) ~= 1 then
        error('failed to set key and IV')
      end

      local out = ffi.new('unsigned char[?]', #plaintext + 16)
      local outl = ffi.new('int[1]')
      if crypto.EVP_EncryptUpdate(cctx, out, outl, plaintext, #plaintext) ~= 1 then
        error('failed to encrypt plaintext')
      end
      local clen = outl[0]
      local final_outl = ffi.new('int[1]')
      if crypto.EVP_EncryptFinal_ex(cctx, out + clen, final_outl) ~= 1 then
        error('failed to finalize encryption')
      end
      clen = clen + final_outl[0]
      local ciphertext = ffi.string(out, clen)

      local tag = ffi.new('unsigned char[16]')
      if crypto.EVP_CIPHER_CTX_ctrl(cctx, 0x10, 16, tag) ~= 1 then
        error('failed to get AEAD tag')
      end
      local tag_str = ffi.string(tag, 16)

      return {
        ciphertext = ciphertext,
        tag = tag_str,
        client_pubkey = client_pubkey,
      }
    end)

    crypto.EVP_CIPHER_CTX_free(cctx)
    if not enc_ok then
      error(enc_res)
    end
    return enc_res
  end)

  crypto.EVP_PKEY_free(pkey[0])
  if not ok then
    error(res_or_err)
  end
  return res_or_err.ciphertext, res_or_err.tag, res_or_err.client_pubkey
end

---@param privkey_raw string
---@param client_pubkey_raw string
---@param iv string
---@param tag string
---@param ciphertext string
---@return string plaintext
function M.decrypt_payload(privkey_raw, client_pubkey_raw, iv, tag, ciphertext)
  local crypto = get_crypto()
  local nid = get_nid_x25519(crypto)

  local peer_key = crypto.EVP_PKEY_new_raw_public_key(nid, nil, client_pubkey_raw, #client_pubkey_raw)
  if peer_key == nil then
    error('failed to load client public key')
  end

  local priv_key = crypto.EVP_PKEY_new_raw_private_key(nid, nil, privkey_raw, #privkey_raw)
  if priv_key == nil then
    crypto.EVP_PKEY_free(peer_key)
    error('failed to load private key')
  end

  local ok, res_or_err = pcall(function()
    local dctx = crypto.EVP_PKEY_CTX_new(priv_key, nil)
    if dctx == nil then
      error('failed to create derive context')
    end

    local sym_key = ffi.new('unsigned char[32]')
    local derive_ok, derive_err = pcall(function()
      if crypto.EVP_PKEY_derive_init(dctx) ~= 1 then
        error('failed to initialize derive context')
      end
      if crypto.EVP_PKEY_derive_set_peer(dctx, peer_key) ~= 1 then
        error('failed to set peer key')
      end
      local secret_len = ffi.new('size_t[1]', 0)
      if crypto.EVP_PKEY_derive(dctx, nil, secret_len) ~= 1 then
        error('failed to get shared secret length')
      end
      local secret = ffi.new('unsigned char[?]', secret_len[0])
      if crypto.EVP_PKEY_derive(dctx, secret, secret_len) ~= 1 then
        error('failed to derive shared secret')
      end
      crypto.SHA256(secret, secret_len[0], sym_key)
    end)

    crypto.EVP_PKEY_CTX_free(dctx)
    if not derive_ok then
      error(derive_err)
    end

    local cctx = crypto.EVP_CIPHER_CTX_new()
    if cctx == nil then
      error('failed to create cipher context')
    end

    local dec_ok, dec_res = pcall(function()
      if crypto.EVP_DecryptInit_ex(cctx, crypto.EVP_aes_256_gcm(), nil, nil, nil) ~= 1 then
        error('failed to initialize AES-256-GCM cipher')
      end
      if crypto.EVP_CIPHER_CTX_ctrl(cctx, 0x9, #iv, nil) ~= 1 then
        error('failed to set IV length')
      end
      if crypto.EVP_DecryptInit_ex(cctx, nil, nil, sym_key, iv) ~= 1 then
        error('failed to set key and IV')
      end

      local out = ffi.new('unsigned char[?]', #ciphertext + 16)
      local outl = ffi.new('int[1]')
      if crypto.EVP_DecryptUpdate(cctx, out, outl, ciphertext, #ciphertext) ~= 1 then
        error('failed to decrypt ciphertext')
      end
      local clen = outl[0]
      if crypto.EVP_CIPHER_CTX_ctrl(cctx, 0x11, #tag, ffi.cast('void*', tag)) ~= 1 then
        error('failed to set AEAD tag')
      end
      local final_outl = ffi.new('int[1]')
      if crypto.EVP_DecryptFinal_ex(cctx, out + clen, final_outl) ~= 1 then
        error('failed to authenticate AEAD tag')
      end
      clen = clen + final_outl[0]
      return ffi.string(out, clen)
    end)

    crypto.EVP_CIPHER_CTX_free(cctx)
    if not dec_ok then
      error(dec_res)
    end
    return dec_res
  end)

  crypto.EVP_PKEY_free(peer_key)
  crypto.EVP_PKEY_free(priv_key)
  if not ok then
    error(res_or_err)
  end
  return res_or_err
end

---Generate an ephemeral X25519 keypair for tests or simulation.
---@return { public: string, public_raw: string, private: string, private_b85: string }
function M.generate_keypair()
  local crypto = get_crypto()
  local nid = get_nid_x25519(crypto)

  local pctx = crypto.EVP_PKEY_CTX_new_id(nid, nil)
  if pctx == nil then
    error('failed to create keygen context')
  end
  if crypto.EVP_PKEY_keygen_init(pctx) ~= 1 then
    crypto.EVP_PKEY_CTX_free(pctx)
    error('failed to initialize keygen context')
  end
  local pkey = ffi.new('EVP_PKEY*[1]')
  if crypto.EVP_PKEY_keygen(pctx, pkey) ~= 1 or pkey[0] == nil then
    crypto.EVP_PKEY_CTX_free(pctx)
    error('failed to generate key')
  end
  crypto.EVP_PKEY_CTX_free(pctx)

  local publen = ffi.new('size_t[1]', 32)
  local pubbuf = ffi.new('unsigned char[32]')
  if crypto.EVP_PKEY_get_raw_public_key(pkey[0], pubbuf, publen) ~= 1 then
    crypto.EVP_PKEY_free(pkey[0])
    error('failed to get raw public key')
  end
  local pub_raw = ffi.string(pubbuf, publen[0])

  local privlen = ffi.new('size_t[1]', 32)
  local privbuf = ffi.new('unsigned char[32]')
  if crypto.EVP_PKEY_get_raw_private_key(pkey[0], privbuf, privlen) ~= 1 then
    crypto.EVP_PKEY_free(pkey[0])
    error('failed to get raw private key')
  end
  local priv_raw = ffi.string(privbuf, privlen[0])
  crypto.EVP_PKEY_free(pkey[0])

  return {
    public = M.b85encode(pub_raw),
    public_raw = pub_raw,
    private = priv_raw,
    private_b85 = M.b85encode(priv_raw),
  }
end

---Encrypt command if password is present, otherwise return command unchanged.
---@param command table
---@return table
function M.encrypt(command)
  if type(command.password) ~= 'string' or command.password == '' then
    return command
  end

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

  local peer_pubkey = M.b85decode(b85_key)
  if #peer_pubkey ~= 32 then
    error('invalid KITTY_PUBLIC_KEY: decoded key length is not 32 bytes')
  end

  local to_encrypt = vim.deepcopy(command)
  local timestamp
  if to_encrypt.timestamp then
    timestamp = string.format('%.0f', to_encrypt.timestamp)
  else
    local t = vim.uv.clock_gettime('realtime')
    if not t then
      error('failed to get system time')
    end
    timestamp = string.format('%d%09d', t.sec, t.nsec)
  end
  to_encrypt.timestamp = nil

  local iv = to_encrypt._iv or vim.uv.random(12)
  to_encrypt._iv = nil
  if not iv then
    error('failed to generate random bytes for IV')
  end

  -- Kitty 0.50 requires a JSON integer. Encoding nanoseconds as a Lua number
  -- produces scientific notation, which Kitty parses as a float and rejects.
  local plaintext = vim.json.encode(to_encrypt):sub(1, -2) .. ',"timestamp":' .. timestamp .. '}'
  local ciphertext, tag, client_pubkey = M.encrypt_payload(peer_pubkey, iv, plaintext)

  return {
    version = command.version or { 0, 45, 0 },
    iv = M.b85encode(iv),
    tag = M.b85encode(tag),
    pubkey = M.b85encode(client_pubkey),
    encrypted = M.b85encode(ciphertext),
  }
end

---Decrypt an encrypted envelope table using a raw 32-byte private key.
---@param envelope table
---@param privkey string
---@return table
function M.decrypt(envelope, privkey)
  if type(envelope) ~= 'table' or not envelope.encrypted then
    error('invalid encrypted envelope')
  end
  local client_pubkey = M.b85decode(envelope.pubkey)
  local iv = M.b85decode(envelope.iv)
  local tag = M.b85decode(envelope.tag)
  local ciphertext = M.b85decode(envelope.encrypted)
  local plaintext = M.decrypt_payload(privkey, client_pubkey, iv, tag, ciphertext)
  return vim.json.decode(plaintext, { luanil = { object = true, array = true } })
end

return M
