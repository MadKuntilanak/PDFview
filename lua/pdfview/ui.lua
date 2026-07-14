local Util = require "pdfview.utils"

local M = {}

local _ui = {
  menu_filetype = "pdfview_menu",
  ns = "PDFviewU",
}

---@alias WinCfg { buf: integer, enter: boolean, wincfg: vim.api.keyset.win_config }
---@alias WinSizeCfg { row: integer, col: integer, height: integer, width: integer, title: string, title_pos: string, buf?: integer}

---@return {width: integer, height: integer}
local function get_editor_size()
  local ui = vim.api.nvim_list_uis()[1]
  return {
    width = ui.width,
    height = ui.height,
  }
end

---@param win_opts WinCfg
---@param lines? table
---@return integer, integer
local function new_open(win_opts, lines)
  lines = lines or {}

  local opts = win_opts

  if not opts.buf then
    opts.buf = vim.api.nvim_create_buf(false, true)
  end

  vim.api.nvim_buf_set_lines(opts.buf, 0, -1, false, lines)

  local win = vim.api.nvim_open_win(opts.buf, opts.enter, opts.wincfg)
  return opts.buf, win
end

local view = {}

---@param opts {buf: integer, win:integer, hval: table<integer, {idx: integer, item: string, shortcut: string, method: string}>}
function view.setup_ui_mappings(opts)
  local keymaps = require "pdfview.keymaps"
  local pdfview = require "pdfview"

  ---@type PDFviewKeySpec[]
  local keys = {}

  keys = {
    -- Enter
    {
      key = "<CR>",
      fun = function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
        local cur_line = vim.api.nvim_win_get_cursor(0)[1]
        Util.close_win { win = { opts.win }, buf = { opts.buf } }

        vim.schedule(function()
          if opts.hval[cur_line].method == "delete_item_bookmark" then
            require("pdfview.pickers.default").delete_item_bookmark()
          elseif pdfview[opts.hval[cur_line].method] then
            pdfview[opts.hval[cur_line].method]()
          end
        end)
      end,
      desc = "select item",
      buf = opts.buf,
    },
    -- Quit
    {
      key = { "q", "<Esc>", "<C-q>" },
      fun = function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
        Util.close_win { win = { opts.win }, buf = { opts.buf } }
      end,
      desc = "quit",
      buf = opts.buf,
    },

    -- Navigate
    {
      key = { "k", "<c-k>", "<c-p>" },
      fun = function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("k", true, false, true), "n", true)
      end,
      desc = "quit",
      buf = opts.buf,
    },
    {
      key = { "j", "<c-j>", "<c-n>" },
      fun = function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("j", true, false, true), "n", true)
      end,
      desc = "quit",
      buf = opts.buf,
    },
  }

  for _, h in pairs(opts.hval) do
    keys[#keys + 1] = {
      key = h.shortcut,
      fun = function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
        Util.close_win { win = { opts.win }, buf = { opts.buf } }
        vim.schedule(function()
          if h.method == "delete_item_bookmark" then
            require("pdfview.pickers.default").delete_item_bookmark()
          elseif pdfview[h.method] then
            pdfview[h.method]()
          end
        end)
      end,
      desc = "select item",
      buf = opts.buf,
    }
  end

  keymaps.append_to(keys)
end

---@param buf integer
---@param lines string[]
---@param padding_line integer
local function apply_higlights(buf, lines, padding_line)
  local ns = vim.api.nvim_create_namespace(_ui.ns)
  Util.del_namespace(buf, ns)

  for lnum, line in ipairs(lines) do
    if not line or line == "" then
      goto continue
    end

    local row = lnum - 1

    local _, bullet_end = line:find("●", 1, true)
    if not bullet_end then
      goto continue
    end

    local item_field_width = padding_line
    local item_start = bullet_end + 2
    local item_end = item_start + item_field_width
    local shortcut_start = item_end + 1

    -- Highlight name item
    Util.set_extmark(buf, ns, row, item_start, {
      end_col = item_end,
      hl_group = "Function",
      priority = 8,
    })

    -- Highlight shortcut
    Util.set_extmark(buf, ns, row, shortcut_start, {
      end_col = #line,
      hl_group = "Boolean",
      priority = 8,
    })

    ::continue::
  end
end

---@param cfg PDFviewCfg
function view.menu(cfg)
  local win_buf = vim.api.nvim_create_buf(false, true)

  local lines = {
    "Select file pdf",
    "Select bookmark",
  }

  if vim.bo.filetype ~= "pdfview" then
    lines[#lines + 1] = "Open from last bookmark"
    lines[#lines + 1] = "Open last"
  end

  if vim.bo.filetype == "pdfview" then
    lines[#lines + 1] = "Open in zathura"
    lines[#lines + 1] = "Go to"
    lines[#lines + 1] = "Text search"
    lines[#lines + 1] = "Select text search"

    if cfg.picker and cfg.picker == "default" then
      lines[#lines + 1] = "Delete item bookmark"
    end
  end

  ---@type table<integer, {idx: integer, item: string, shortcut: string, method: string}>
  local hval = {}
  local display_lines = {}

  local seen = {}
  local resolve_shortcut = function(item)
    for i = 1, #item do
      local shortcut = item:sub(i, i)
      shortcut = shortcut:lower()
      if not seen[shortcut] then
        seen[shortcut] = true
        return shortcut
      end
    end
  end

  local padding_line = 0
  for _, str_line in pairs(lines) do
    local str_w = vim.fn.strdisplaywidth(str_line)
    if padding_line < str_w then
      padding_line = str_w + 2
    end
  end

  table.sort(lines, function(a, b)
    return a:lower() < b:lower()
  end)

  local padding_display_lines = 0
  for i, item in ipairs(lines) do
    local shortcut = resolve_shortcut(item)
    local text_line = string.format("   %s  %-" .. padding_line .. "s %s", "●", item, shortcut)
    table.insert(display_lines, text_line)
    hval[i] = {
      idx = i,
      item = item,
      shortcut = shortcut,
      method = item:gsub(" ", "_"):lower(),
    }
    local len_text_line = vim.fn.strdisplaywidth(text_line)
    if padding_display_lines < len_text_line then
      padding_display_lines = len_text_line
    end
  end

  local editor_size = get_editor_size()
  local width = math.floor(editor_size.width * 20 / 100)
  width = math.min(width, padding_display_lines + 4)
  local height = #display_lines + 1

  ---@param height_editor integer
  ---@param width_editor integer
  local function get_center_col_row(height_editor, width_editor)
    local row = math.ceil((editor_size.height - height_editor) / 2) - 5
    local col = math.ceil((editor_size.width - width_editor) / 2)
    return col, row
  end

  local col, row = get_center_col_row(height, width)

  ---@type WinCfg
  local wincfg = {
    buf = win_buf,
    enter = true,
    wincfg = {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = Util.format_title "menu",
      title_pos = "center",
      footer = " <C-q>/<Esc> quit ",
      footer_pos = "center",
    },
  }
  local main_buf, main_win = new_open(wincfg, display_lines)

  vim.bo[main_buf].filetype = _ui.menu_filetype
  cfg.ui.menu = hval

  vim.api.nvim_set_option_value("cursorline", true, { win = main_win, scope = "local" })
  vim.api.nvim_set_option_value(
    "winhighlight",
    cfg.window.winhighlight and cfg.window.winhighlight
      or "Normal:Error,"
        .. "NormalFloat:NormalFloat,"
        .. "FloatBorder:FloatBorder,"
        .. "FloatTitle:FloatTitle,"
        .. "FloatFooter:FloatBorder,",
    { win = main_win, scope = "local" }
  )

  vim.api.nvim_set_option_value("modifiable", false, { buf = main_buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = main_buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = main_buf })

  apply_higlights(main_buf, display_lines, padding_line)

  local opts = { buf = main_buf, win = main_win, hval = hval }
  view.setup_ui_mappings(opts)
end

---@param cfg PDFviewCfg
function M.call(call_name, cfg)
  if not view[call_name] then
    return
  end
  cfg.ui = _ui
  view[call_name](cfg)
end

return M
