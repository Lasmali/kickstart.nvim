-- Improved in-buffer rendering of Markdown
-- See `:help render-markdown`

---@module 'lazy'
---@type LazySpec
return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      completions = { blink = { enabled = true } },
    },
    config = function(_, opts)
      -- render-markdown looks up code block icons by filetype via nvim-web-devicons,
      -- which has no entry for Gherkin. Register the Nerd Font cucumber icon (U+E7B7).
      local ok, devicons = pcall(require, 'nvim-web-devicons')
      if ok then
        devicons.setup()
        devicons.set_icon {
          gherkin = { icon = '\u{e7b7}', color = '#23d96c', cterm_color = '41', name = 'Gherkin' },
        }
        -- ```gherkin -> gherkin, ```feature / ```cucumber -> cucumber filetype
        devicons.set_icon_by_filetype { gherkin = 'gherkin', cucumber = 'gherkin' }
      end
      require('render-markdown').setup(opts)
    end,
    keys = {
      { '<leader>tm', '<cmd>RenderMarkdown toggle<cr>', ft = 'markdown', desc = '[T]oggle [M]arkdown rendering' },
    },
  },
}
