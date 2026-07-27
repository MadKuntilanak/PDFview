local Util = require "pdfview.utils"

local M = {}

local _ui = {
  menu_filetype = "pdfview_menu",
  menu_show_filetype = "pdfview_menu_help",
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

---@param buf integer
---@param lines string[]
---@param padding_line integer
local function apply_menu_higlights(buf, lines, padding_line)
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

---@param buf integer
---@param lines string[]
local function apply_show_menu_highlights(buf, lines)
  local ns = vim.api.nvim_create_namespace(_ui.ns)
  Util.del_namespace(buf, ns)

  local headers = {
    [1] = "Comment", -- "Press q or <Esc>..."
    [3] = "Title", -- "Global keymaps:"
  }

  for lnum, line in ipairs(lines) do
    if not line or line == "" then
      goto continue
    end

    local row = lnum - 1

    -- highlight header lines
    if headers[lnum] then
      Util.set_extmark(buf, ns, row, 0, {
        end_col = #line,
        hl_group = headers[lnum],
        priority = 8,
      })
      goto continue
    end

    if not line:match "^   %S" then
      goto continue
    end

    -- find key start (first non-space)
    local key_start = line:find "%S"
    if not key_start then
      goto continue
    end

    -- find desc_start by scanning for double-space gap after key
    local key_end = key_start
    local desc_start = nil
    local i = key_start

    while i <= #line do
      if line:sub(i, i + 1) == "  " then
        local j = i -- found gap, skip all spaces to find desc start
        while j <= #line and line:sub(j, j) == " " do
          j = j + 1
        end
        if j <= #line then
          desc_start = j
        end
        break
      end
      key_end = i
      i = i + 1
    end

    if not desc_start then
      goto continue
    end

    Util.set_extmark(buf, ns, row, key_start - 1, {
      end_col = key_end,
      hl_group = "Function",
      priority = 8,
    })

    Util.set_extmark(buf, ns, row, desc_start - 1, {
      end_col = #line,
      hl_group = "Normal",
      priority = 8,
    })

    ::continue::
  end
end

---@param editor_size {width: integer, height: integer}
---@param height_editor integer
---@param width_editor integer
local function get_center_col_row(editor_size, height_editor, width_editor)
  local row = math.ceil((editor_size.height - height_editor) / 2) - 5
  local col = math.ceil((editor_size.width - width_editor) / 2)
  return col, row
end

local view = { keys = {} }

---@param opts {buf: integer, win:integer, hval: table<integer, {idx: integer, item: string, shortcut: string, method: string}>}
function view.setup_ui_mappings(opts)
  local keymaps = require "pdfview.keymaps"
  local pdfview = require "pdfview"
  local cfg = require("pdfview.config").defaults

  ---@type PDFviewKeySpec[]
  view.keys = {
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
      type = "menu",
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
      type = "menu",
    },

    -- Navigate
    {
      key = { "k", "<C-k>", "<C-p>" },
      fun = function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("k", true, false, true), "n", true)
      end,
      desc = "next item",
      buf = opts.buf,
      type = "menu",
    },
    {
      key = { "j", "<C-j>", "<C-n>" },
      fun = function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("j", true, false, true), "n", true)
      end,
      desc = "prev item",
      buf = opts.buf,
      type = "menu",
    },

    {
      key = cfg.keymaps.show_helps,
      fun = function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
        view.show_keymap_helps(cfg)
      end,
      desc = "show helps",
      buf = opts.buf,
      type = "menu",
    },
  }

  for _, h in pairs(opts.hval) do
    view.keys[#view.keys + 1] = {
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
      desc = "shortcut key: " .. h.method,
      buf = opts.buf,
      type = "menu",
    }
  end

  keymaps.append_to(view.keys)
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
  local height = #display_lines + 1

  local col, row = get_center_col_row(editor_size, height, width)
  local title_label = " <C-q>/<Esc> quit "
  local title_footer = vim.bo.filetype == "pdfview"
      and " " .. cfg.keymaps.show_helps .. " show globals  · " .. title_label
    or title_label

  width = math.max(vim.fn.strdisplaywidth(title_footer), padding_display_lines + 4)

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
      footer = title_footer,
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
      or "Normal:Error,NormalFloat:NormalFloat,FloatBorder:FloatBorder,FloatTitle:FloatTitle,",
    { win = main_win, scope = "local" }
  )

  vim.api.nvim_set_option_value("modifiable", false, { buf = main_buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = main_buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = main_buf })

  apply_menu_higlights(main_buf, display_lines, padding_line)

  local opts = { buf = main_buf, win = main_win, hval = hval }
  view.setup_ui_mappings(opts)
end

---@param cfg PDFviewCfg
function view.show_keymap_helps(cfg)
  local key_show_helps = cfg.show_helps or {}

  if Util.is_blank(key_show_helps) then
    return
  end

  local function format_key(x)
    if type(x) == "string" then
      return x
    end
    local key_tbl = {}
    for _, y in ipairs(x) do
      key_tbl[#key_tbl + 1] = y
    end
    return table.concat(key_tbl, " ")
  end

  local pad = 0
  for _, x in ipairs(key_show_helps) do
    local key = format_key(x.key)
    if key then
      local str_w = vim.fn.strdisplaywidth(key)
      if pad < str_w then
        pad = str_w + 2
      end
    end
  end

  local display_lines = {}
  local seen = {}
  local pad_str = 0

  for _, x in ipairs(key_show_helps) do
    local key = format_key(x.key)

    if not seen[key .. " " .. x.desc] then
      seen[key .. " " .. x.desc] = true

      if x.type == "global" then
        local lines = string.format("   %-" .. pad + 10 .. "s %s", key, x.desc)
        local str_w = vim.fn.strdisplaywidth(lines)
        if pad_str < str_w then
          pad_str = str_w
        end
        display_lines[#display_lines + 1] = lines
      end
    end
  end

  table.insert(display_lines, 1, "Press q or <Esc> to close this window.")
  table.insert(display_lines, 2, "")
  table.insert(display_lines, 3, "Global keymaps:")

  local editor_size = get_editor_size()
  local height = math.min(#display_lines, math.floor(editor_size.height / 2)) + 1
  local width = math.min(pad_str, math.floor(editor_size.width / 2)) + 2
  local col, row = get_center_col_row(editor_size, height, width)
  local title_str = "global keymaps"

  local wincfg = {
    buf = vim.api.nvim_create_buf(false, true),
    enter = true,
    wincfg = {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = Util.format_title(title_str),
      title_pos = "center",
      focusable = true,
      noautocmd = true,
    },
  }

  local buf, win = new_open(wincfg, {})
  vim.bo[buf].modifiable = true

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
  vim.bo[buf].filetype = _ui.menu_show_filetype
  vim.bo[buf].modifiable = false

  apply_show_menu_highlights(buf, display_lines)

  vim.keymap.set("n", "<Esc>", function()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end)
  vim.keymap.set("n", "q", function()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end)
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
