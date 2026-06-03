-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

---@module 'lazy'
---@type LazySpec
return {
  {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
    },
  },
  {
    'saghen/blink.cmp',
    dependencies = {
      'giuxtaposition/blink-cmp-copilot',
    },
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.default = opts.sources.default or { 'lsp', 'path', 'snippets' }

      if not vim.tbl_contains(opts.sources.default, 'copilot') then table.insert(opts.sources.default, 'copilot') end

      opts.sources.providers = opts.sources.providers or {}
      opts.sources.providers.copilot = {
        name = 'copilot',
        module = 'blink-cmp-copilot',
        score_offset = 100,
        async = true,
      }

      return opts
    end,
  },
}
