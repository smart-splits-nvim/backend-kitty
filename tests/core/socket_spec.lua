describe('socket protocol', function()
  local socket = require('smart-splits-backend-kitty.socket')
  local crypto = require('smart-splits-backend-kitty.crypto')
  local ESC = string.char(0x1b)

  it('parses unix and tcp listen addresses', function()
    local kind, path = socket.parse_address('unix:/tmp/mykitty')
    assert.are.equal('unix', kind)
    assert.are.equal('/tmp/mykitty', path)

    kind, path = socket.parse_address('unix:@mykitty')
    assert.are.equal('unix', kind)
    assert.are.equal('@mykitty', path)

    kind, path = socket.parse_address('/tmp/mykitty')
    assert.are.equal('unix', kind)
    assert.are.equal('/tmp/mykitty', path)

    local host, port
    kind, host, port = socket.parse_address('tcp:127.0.0.1:1234')
    assert.are.equal('tcp', kind)
    assert.are.equal('127.0.0.1', host)
    assert.are.equal(1234, port)

    kind, host, port = socket.parse_address('localhost:4321')
    assert.are.equal('tcp', kind)
    assert.are.equal('localhost', host)
    assert.are.equal(4321, port)

    kind = socket.parse_address('not-a-socket')
    assert.are.equal(nil, kind)
  end)

  it('frames a command the way kitty reads it', function()
    local frame = socket.encode({ cmd = 'ls', version = { 0, 45, 0 }, no_response = false })
    assert.are.equal(ESC .. 'P@kitty-cmd', frame:sub(1, #'P@kitty-cmd' + 1))
    assert.are.equal(ESC .. '\\', frame:sub(-2))
    local body = frame:match(ESC .. 'P@kitty%-cmd(.*)' .. ESC .. '\\')
    local command = vim.json.decode(body)
    assert.are.equal('ls', command.cmd)
    assert.are.equal(0, command.version[1])
    assert.are.equal(45, command.version[2])
    assert.are.equal(0, command.version[3])
  end)

  it('decodes an ls response', function()
    local inner = vim.json.encode({ { id = 7, tabs = {} } })
    local raw = ESC .. 'P@kitty-cmd' .. vim.json.encode({ ok = true, data = inner }) .. ESC .. '\\'
    local data = socket.decode(raw)
    assert.are.equal(7, data[1].id)
  end)

  it('surfaces a kitty error', function()
    local raw = ESC .. 'P@kitty-cmd' .. vim.json.encode({ ok = false, error = 'nope' }) .. ESC .. '\\'
    local data, err = socket.decode(raw)
    assert.are.equal(nil, data)
    assert.are.equal('nope', err)
  end)

  describe('abstract unix sockets', function()
    local uv = vim.uv
    local original_listen_on = vim.env.KITTY_LISTEN_ON
    local server

    after_each(function()
      vim.env.KITTY_LISTEN_ON = original_listen_on
      if server and not server:is_closing() then
        server:close()
      end
      server = nil
    end)

    it('connects to a kitty listen address written with a leading @', function()
      local probe = uv.new_pipe(false)
      if vim.fn.has('linux') == 0 or not probe.bind2 or not probe.connect2 then
        probe:close()
        pending('abstract sockets need Linux and libuv with pipe bind2/connect2')
        return
      end
      probe:close()

      local name = ('smart-splits-backend-kitty-test-%d'):format(uv.os_getpid())
      server = uv.new_pipe(false)
      assert(server:bind2('\0' .. name, 0))

      local received = ''
      server:listen(1, function()
        local peer = uv.new_pipe(false)
        server:accept(peer)
        peer:read_start(function(_, data)
          if data then
            received = received .. data
          end
        end)
      end)

      vim.env.KITTY_LISTEN_ON = 'unix:@' .. name
      local command = { cmd = 'focus-window', version = { 0, 45, 0 } }
      socket.send(command)

      assert.is_true(vim.wait(2000, function()
        return received:sub(-2) == ESC .. '\\'
      end, 10))
      assert.are.equal(socket.encode(command), received)
    end)
  end)

  describe('base85', function()
    it('encodes and decodes strings with various lengths and paddings', function()
      for l = 0, 16 do
        local original = string.rep('A', l)
        local encoded = crypto.b85encode(original)
        local decoded = crypto.b85decode(encoded)
        assert.are.equal(original, decoded)
      end
    end)

    it('matches Python RFC 1924 standard vectors', function()
      local test_str = 'Hello, world! 12345'
      local expected = 'NM&qnZ!92pZ*pv8As{g_Gc+{'
      assert.are.equal(expected, crypto.b85encode(test_str))
      assert.are.equal(test_str, crypto.b85decode(expected))
    end)

    it('handles decoding errors for invalid characters', function()
      assert.has_error(function()
        crypto.b85decode('invalid space in base85')
      end)
    end)
  end)

  describe('encrypted commands with password', function()
    local orig_pubkey = vim.env.KITTY_PUBLIC_KEY
    local server_key

    before_each(function()
      server_key = crypto.generate_keypair()
      vim.env.KITTY_PUBLIC_KEY = '1:' .. server_key.public
    end)

    after_each(function()
      vim.env.KITTY_PUBLIC_KEY = orig_pubkey
    end)

    it('encodes as plain JSON when password is not set or empty', function()
      local cmd1 = { cmd = 'ls', version = { 0, 45, 0 } }
      local frame1 = socket.encode(cmd1)
      local body1 = frame1:match(ESC .. 'P@kitty%-cmd(.*)' .. ESC .. '\\')
      local decoded1 = vim.json.decode(body1)
      assert.are.equal('ls', decoded1.cmd)
      assert.is_nil(decoded1.encrypted)

      local cmd2 = { cmd = 'ls', version = { 0, 45, 0 }, password = '' }
      local frame2 = socket.encode(cmd2)
      local body2 = frame2:match(ESC .. 'P@kitty%-cmd(.*)' .. ESC .. '\\')
      local decoded2 = vim.json.decode(body2)
      assert.are.equal('ls', decoded2.cmd)
      assert.is_nil(decoded2.encrypted)
    end)

    it('requires KITTY_PUBLIC_KEY when password is set', function()
      vim.env.KITTY_PUBLIC_KEY = nil
      assert.has_error(function()
        socket.encode({ cmd = 'ls', password = 'secret' })
      end, 'KITTY_PUBLIC_KEY is unset')
    end)

    it('rejects unsupported protocol version', function()
      vim.env.KITTY_PUBLIC_KEY = '2:' .. server_key.public
      assert.has_error(function()
        socket.encode({ cmd = 'ls', password = 'secret' })
      end, 'unsupported KITTY_PUBLIC_KEY protocol: 2')
    end)

    it('rejects invalid public key length', function()
      vim.env.KITTY_PUBLIC_KEY = '1:' .. crypto.b85encode('short')
      assert.has_error(function()
        socket.encode({ cmd = 'ls', password = 'secret' })
      end, 'invalid KITTY_PUBLIC_KEY: decoded key length is not 32 bytes')
    end)

    it('encrypts command and decrypts back to original payload with timestamp', function()
      local original_cmd = {
        cmd = 'resize-window',
        version = { 0, 45, 0 },
        password = 'super-secret-password',
        payload = { increment = 5, axis = 'horizontal' },
      }
      local frame = socket.encode(original_cmd)
      assert.are.equal(ESC .. 'P@kitty-cmd', frame:sub(1, #'P@kitty-cmd' + 1))
      assert.are.equal(ESC .. '\\', frame:sub(-2))

      local body = frame:match(ESC .. 'P@kitty%-cmd(.*)' .. ESC .. '\\')
      local outer = vim.json.decode(body)
      assert.is_not_nil(outer.version)
      assert.is_not_nil(outer.iv)
      assert.is_not_nil(outer.tag)
      assert.is_not_nil(outer.pubkey)
      assert.is_not_nil(outer.encrypted)

      local plaintext = crypto.decrypt_payload(
        server_key.private,
        crypto.b85decode(outer.pubkey),
        crypto.b85decode(outer.iv),
        crypto.b85decode(outer.tag),
        crypto.b85decode(outer.encrypted)
      )
      -- Lua decodes both JSON integers and floats as numbers, so inspect the wire format.
      assert.matches('"timestamp":%d+[,}]', plaintext)
      assert.is_nil(original_cmd.timestamp)

      local decrypted = crypto.decrypt(outer, server_key.private)
      assert.are.equal(original_cmd.cmd, decrypted.cmd)
      assert.are.equal(original_cmd.password, decrypted.password)
      assert.are.equal(original_cmd.payload.increment, decrypted.payload.increment)
      assert.is_number(decrypted.timestamp)

      -- Check timestamp freshness (within 5 seconds)
      local t = vim.uv.clock_gettime('realtime')
      local now_ns = t.sec * 1000000000 + t.nsec
      local diff = math.abs(now_ns - decrypted.timestamp)
      assert.is_true(diff < 5 * 1000000000)
    end)

    it('encodes a supplied nanosecond timestamp as a JSON integer', function()
      local command = { cmd = 'ls', password = 'secret', timestamp = 1794323089000000000 }
      local outer = crypto.encrypt(command)
      local plaintext = crypto.decrypt_payload(
        server_key.private,
        crypto.b85decode(outer.pubkey),
        crypto.b85decode(outer.iv),
        crypto.b85decode(outer.tag),
        crypto.b85decode(outer.encrypted)
      )
      assert.matches('"timestamp":1794323089000000000[,}]', plaintext)
      assert.are.equal(1794323089000000000, command.timestamp)
    end)

    it('fails decryption when ciphertext or tag is tampered with', function()
      local frame = socket.encode({ cmd = 'ls', password = 'secret' })
      local outer = vim.json.decode(frame:match(ESC .. 'P@kitty%-cmd(.*)' .. ESC .. '\\'))

      local raw_enc = crypto.b85decode(outer.encrypted)
      local tampered_enc = string.char((raw_enc:byte(1) + 1) % 256) .. raw_enc:sub(2)
      outer.encrypted = crypto.b85encode(tampered_enc)

      assert.has_error(function()
        crypto.decrypt(outer, server_key.private)
      end)
    end)
  end)
end)
