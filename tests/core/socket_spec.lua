describe('socket protocol', function()
  local socket = require('smart-splits-backend-kitty.socket')
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
end)
