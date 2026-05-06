local M = {}

function M.setup()
  local latest_terminal_job_id = nil

  local function remember_terminal(bufnr)
    local job_id = vim.b[bufnr].terminal_job_id
    if job_id then latest_terminal_job_id = job_id end
  end

  local function expand_command(bufnr, command)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if filename == '' then return command end

    local escaped_filename = vim.fn.shellescape(vim.fn.fnamemodify(filename, ':p'))
    return command:gsub('%%', function() return escaped_filename end)
  end

  local function send_to_latest_terminal(bufnr)
    local command = vim.b[bufnr].term_cmd_on_write
    if not command or command == '' then return end

    if not latest_terminal_job_id then
      vim.notify('No terminal available for TermCmdOnWrite', vim.log.levels.WARN)
      return
    end

    local ok = pcall(vim.fn.chansend, latest_terminal_job_id, expand_command(bufnr, command) .. '\n')
    if not ok then vim.notify('Latest terminal is no longer available for TermCmdOnWrite', vim.log.levels.ERROR) end
  end

  local group = vim.api.nvim_create_augroup('termieditor', { clear = true })

  vim.api.nvim_create_autocmd({ 'TermOpen', 'BufEnter' }, {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].buftype == 'terminal' then remember_terminal(args.buf) end
    end,
  })

  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    callback = function(args) send_to_latest_terminal(args.buf) end,
  })

  vim.api.nvim_create_user_command('TermCmdOnWrite', function(opts)
    local args = vim.trim(opts.args)

    if args == '' then
      local command = vim.b.term_cmd_on_write
      if command and command ~= '' then
        vim.notify('TermCmdOnWrite: ' .. command, vim.log.levels.INFO)
      else
        vim.notify('TermCmdOnWrite is not set for this buffer', vim.log.levels.INFO)
      end
      return
    end

    if args == 'off' then
      vim.b.term_cmd_on_write = nil
      vim.notify('TermCmdOnWrite cleared for this buffer', vim.log.levels.INFO)
      return
    end

    vim.b.term_cmd_on_write = args
    vim.notify('TermCmdOnWrite: ' .. args, vim.log.levels.INFO)
  end, {
    nargs = '*',
    desc = 'Run a buffer-local command in the latest terminal after writing',
  })

  vim.cmd [[cnoreabbrev <expr> tcow getcmdtype() == ':' && getcmdline() ==# 'tcow' ? 'TermCmdOnWrite' : 'tcow']]
end

return M
