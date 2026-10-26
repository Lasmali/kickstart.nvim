-- gherkin: highlight ```gherkin fenced code blocks inside Markdown buffers.
--
-- There is no treesitter parser for Gherkin in nvim-treesitter, and the
-- third-party ones reject fragments (a Scenario without a `Feature:` line) and
-- wrapped step lines. This module highlights those blocks with simple line
-- patterns via extmarks instead, so it works on partial snippets too. It sits
-- on top of render-markdown.nvim's code block background.
--
-- Recognised fence languages: gherkin, cucumber, feature
--
-- Colours link to standard treesitter groups so they follow your colorscheme.
-- Override any of them, e.g.:
--   vim.api.nvim_set_hl(0, 'GherkinParam', { fg = '#e0af68', italic = true })

local M = {}

local ns = vim.api.nvim_create_namespace 'custom_gherkin_md'

local fence_langs = { gherkin = true, cucumber = true, feature = true }

local links = {
  GherkinKeyword = '@keyword', -- Feature:, Scenario Outline:, Examples:, ...
  GherkinTitle = '@markup.heading', -- text after "Scenario Outline:"
  GherkinStep = '@function', -- Given / When / Then / And / But / *
  GherkinParam = '@variable.parameter', -- <placeholders>
  GherkinString = '@string', -- "quoted values"
  GherkinTag = '@attribute', -- @tags
  GherkinComment = '@comment', -- # comments
  GherkinTableHeader = '@markup.heading', -- first row of an Examples table
  GherkinDelimiter = '@punctuation.special', -- table pipes
  GherkinText = 'Normal', -- everything else (instead of code-block green)
}

-- Longest first so "Scenario Outline" wins over "Scenario".
local block_keywords = {
  'Scenario Outline',
  'Scenario Template',
  'Background',
  'Scenarios',
  'Examples',
  'Scenario',
  'Example',
  'Feature',
  'Rule',
}

local step_keywords = { 'Given', 'When', 'Then', 'And', 'But' }

local function set_highlights()
  for group, link in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end
end

local function hl(buf, row, s, e, group)
  -- priority above treesitter (100) so it overrides @markup.raw.block
  vim.api.nvim_buf_set_extmark(buf, ns, row, s, { end_col = e, hl_group = group, priority = 150 })
end

-- Highlight a pattern everywhere in `line`. Pattern must not contain captures.
local function hl_all(buf, row, line, pattern, group)
  local init = 1
  while true do
    local s, e = line:find(pattern, init)
    if not s then return end
    hl(buf, row, s - 1, e, group)
    init = e + 1
  end
end

local function highlight_line(buf, row, line, state)
  local indent = #line:match '^%s*'
  local rest = line:sub(indent + 1)
  if rest == '' then return end

  if rest:sub(1, 1) == '#' then
    hl(buf, row, indent, #line, 'GherkinComment')
    return
  end

  hl(buf, row, indent, #line, 'GherkinText')

  if rest:sub(1, 1) == '@' then
    hl_all(buf, row, line, '@[^%s]+', 'GherkinTag')
    return
  end

  if rest:sub(1, 1) == '|' then
    if not state.in_table then
      state.in_table = true
      hl(buf, row, indent, #line, 'GherkinTableHeader')
    end
    hl_all(buf, row, line, '|', 'GherkinDelimiter')
    hl_all(buf, row, line, '<[^<>]+>', 'GherkinParam')
    return
  end
  state.in_table = false

  for _, kw in ipairs(block_keywords) do
    if rest:sub(1, #kw + 1) == kw .. ':' then
      local kw_end = indent + #kw + 1
      hl(buf, row, indent, kw_end, 'GherkinKeyword')
      local title_start = kw_end + #(line:sub(kw_end + 1):match '^%s*')
      if title_start < #line then hl(buf, row, title_start, #line, 'GherkinTitle') end
      return
    end
  end

  for _, kw in ipairs(step_keywords) do
    if rest:sub(1, #kw) == kw and (#rest == #kw or rest:sub(#kw + 1, #kw + 1):match '%s') then
      hl(buf, row, indent, indent + #kw, 'GherkinStep')
      break
    end
  end
  if rest:match '^%*%s' then hl(buf, row, indent, indent + 1, 'GherkinStep') end

  hl_all(buf, row, line, '"[^"]*"', 'GherkinString')
  hl_all(buf, row, line, '<[^<>]+>', 'GherkinParam')
end

local query ---@type vim.treesitter.Query?

local function refresh(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'markdown', { error = false })
  if not ok or not parser then return end
  local tree = parser:parse()[1]
  if not tree then return end

  query = query
    or vim.treesitter.query.parse(
      'markdown',
      [[(fenced_code_block (info_string (language) @lang) (code_fence_content) @content)]]
    )

  for _, match in query:iter_matches(tree:root(), buf, 0, -1) do
    local lang_node, content_node
    for id, nodes in pairs(match) do
      local node = type(nodes) == 'table' and nodes[1] or nodes
      if query.captures[id] == 'lang' then
        lang_node = node
      else
        content_node = node
      end
    end
    local lang = lang_node and vim.treesitter.get_node_text(lang_node, buf):lower()
    if lang and fence_langs[lang] and content_node then
      local sr, _, er, ec = content_node:range()
      if ec > 0 then er = er + 1 end
      local state = { in_table = false }
      for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, sr, er, false)) do
        highlight_line(buf, sr + i - 1, line, state)
      end
    end
  end
end

local pending = {} ---@type table<integer, boolean>

local function schedule_refresh(buf)
  if pending[buf] then return end
  pending[buf] = true
  vim.defer_fn(function()
    pending[buf] = nil
    refresh(buf)
  end, 50)
end

function M.setup()
  set_highlights()
  local group = vim.api.nvim_create_augroup('custom_gherkin_md', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = set_highlights })
  vim.api.nvim_create_autocmd({ 'FileType', 'BufEnter', 'TextChanged', 'TextChangedI' }, {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].filetype == 'markdown' then schedule_refresh(args.buf) end
    end,
  })
end

M._refresh = refresh -- exposed for testing

return M
