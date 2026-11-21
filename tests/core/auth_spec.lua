local config = require('smart-splits-backend-kitty.config')
local socket = require('smart-splits-backend-kitty.socket')

-- Load the real request implementation even when other tests replace it with fake_kitty.
local kitty = dofile('lua/smart-splits-backend-kitty/kitty.lua')

describe('password authentication', function()
  local original_system, original_executable, original_exchange, original_send
  local original_listen, original_password, original_global, original_options
  local calls, response, available

  before_each(function()
    original_system, original_executable = vim.system, vim.fn.executable
    original_exchange, original_send = socket.exchange, socket.send
    original_listen, original_password = vim.env.KITTY_LISTEN_ON, vim.env.KITTY_RC_PASSWORD
    original_global, original_options = vim.g.smart_splits_kitty_password, vim.deepcopy(config.options)
    vim.env.KITTY_LISTEN_ON = 'unix:/tmp/test-kitty'
    vim.env.KITTY_RC_PASSWORD = 'unrelated-completion-password'
    vim.g.smart_splits_kitty_password = nil
    config.setup({ password = 'backend-password', provide_password_via_stdin = true })
    calls, available = {}, { kitten = true }
    response = { code = 0, stdout = '', stderr = '' }
    vim.fn.executable = function(name)
      return available[name] and 1 or 0
    end
    vim.system = function(argv, opts)
      calls[#calls + 1] = { argv = argv, opts = opts }
      return {
        wait = function()
          return response
        end,
      }
    end
    socket.exchange = function()
      error('authenticated request reached plaintext socket')
    end
    socket.send = socket.exchange
  end)

  after_each(function()
    vim.system, vim.fn.executable = original_system, original_executable
    socket.exchange, socket.send = original_exchange, original_send
    vim.env.KITTY_LISTEN_ON, vim.env.KITTY_RC_PASSWORD = original_listen, original_password
    vim.g.smart_splits_kitty_password = original_global
    config.setup(original_options)
  end)

  it('passes the configured password through stdin and decodes ls', function()
    response.stdout = '[{"id":7,"tabs":[]}]'
    assert.are.equal(7, kitty.list_os_windows()[1].id)
    assert.are.same(
      { 'kitten', '@', '--to', 'unix:/tmp/test-kitty', '--password-file', '-', '--use-password', 'always', 'ls' },
      calls[1].argv
    )
    assert.are.equal('backend-password', calls[1].opts.stdin)
    assert.are.equal('unrelated-completion-password', vim.env.KITTY_RC_PASSWORD)
    assert.are.equal(2000, calls[1].opts.timeout)
  end)

  it('supports the legacy password setting and kitty fallback', function()
    config.setup({ provide_password_via_stdin = true })
    vim.g.smart_splits_kitty_password = 'legacy-password'
    available = { kitty = true }
    assert.is_true(kitty.focus_window(17))
    assert.are.equal('kitty', calls[1].argv[1])
    assert.are.equal('legacy-password', calls[1].opts.stdin)
    assert.are.same({ 'focus-window', '--match', 'id:17' }, vim.list_slice(calls[1].argv, 9))
  end)

  it('translates action and resize payloads without suppressing errors', function()
    assert.is_true(kitty.neighboring_window('left'))
    assert.are.same({ 'action', 'neighboring_window left' }, vim.list_slice(calls[1].argv, 9))
    assert.is_true(
      kitty.request(
        'resize-window',
        { self = true, match = 'id:17', axis = 'horizontal', increment = -2 },
        { no_response = true }
      )
    )
    assert.are.same(
      { 'resize-window', '--match', 'id:17', '--self', '--axis', 'horizontal', '--increment', '-2' },
      vim.list_slice(calls[2].argv, 9)
    )
  end)

  it('translates split commands and parses the launched window id', function()
    assert.is_true(kitty.request('goto-layout', { layout = 'splits' }, { no_response = true }))
    assert.are.same({ 'goto-layout', 'splits' }, vim.list_slice(calls[1].argv, 9))
    response.stdout = '42\n'
    assert.are.equal(42, kitty.request('launch', { cwd = 'current', location = 'vsplit', args = {} }))
    assert.are.same({ 'launch', '--cwd', 'current', '--location', 'vsplit', '--' }, vim.list_slice(calls[2].argv, 9))
    response.stdout = ''
    kitty.request('action', { action = 'move_window left', self = true }, { no_response = true })
    assert.are.same({ 'action', '--self', 'move_window left' }, vim.list_slice(calls[3].argv, 9))
  end)

  it('reports authentication failures even for no-response calls', function()
    response = { code = 1, stdout = '', stderr = 'password rejected' }
    local ok, err = pcall(kitty.neighboring_window, 'left')
    assert.is_false(ok)
    assert.is_truthy(tostring(err):find('password rejected', 1, true))
  end)

  it('reports missing clients without falling back to plaintext', function()
    available = {}
    local ok, err = pcall(kitty.list_os_windows)
    assert.is_false(ok)
    assert.is_truthy(tostring(err):find('requires kitten or kitty', 1, true))
    assert.are.equal(0, #calls)
  end)

  it('keeps password authentication on the socket by default', function()
    config.setup({ password = 'backend-password' })
    local sent
    socket.exchange = function(command)
      sent = command
      return {}
    end
    assert.are.same({}, kitty.list_os_windows())
    assert.are.equal('backend-password', sent.password)
    assert.are.equal(0, #calls)
  end)

  it('keeps unauthenticated requests on the socket', function()
    config.setup({ provide_password_via_stdin = true })
    local sent
    socket.exchange = function(command)
      sent = command
      return {}
    end
    socket.send = function(command)
      sent = command
    end
    assert.are.same({}, kitty.list_os_windows())
    assert.is_nil(sent.password)
    assert.is_true(kitty.neighboring_window('left'))
    assert.is_true(sent.no_response)
    assert.are.equal(0, #calls)
  end)
end)
