local Plenary_path = require "plenary.path"

local M = {}

function M.is_iterm2()
  return vim.env.TERM_PROGRAM == "iTerm.app"
end

function M.is_kitty()
  return vim.env.TERM == "xterm-kitty"
end

---@param module_or_message string
---@param message? string
local function notify(hl, module_or_message, message)
  local module

  if message == nil then
    message = module_or_message
  else
    module = module_or_message
  end

  local prefix = module and ("PDFview." .. module) or "PDFview"

  vim.api.nvim_echo({
    { ("(%s) "):format(prefix), hl },
    { message },
  }, true, {})
end

---@param module_or_message string
---@param message? string
function M.info(module_or_message, message)
  notify("Directory", module_or_message, message)
end

---@param module_or_message string
---@param message? string
function M.warn(module_or_message, message)
  notify("WarningMsg", module_or_message, message)
end

---@param module_or_message string
---@param message? string
function M.error(module_or_message, message)
  notify("ErrorMsg", module_or_message, message)
end

---@param msg? string
function M.not_implemented_yet(msg)
  if msg == nil then
    msg = ""
  end
  if #msg > 0 then
    msg = "Not impelemented, -> " .. msg
  else
    msg = "Not impelemented yet"
  end
  M.warn(msg)
end

---@return boolean
function M.is_blank(s)
  return (
    s == nil
    or s == vim.NIL
    or (type(s) == "string" and string.match(s, "%S") == nil)
    or (type(s) == "table" and next(s) == nil)
  )
end

---@param filename string
---@return boolean | string
function M.exists(filename)
  local stat
  if filename then
    stat = vim.loop.fs_stat(filename)
  end

  return stat and stat.type or false
end

---@param filename string
---@return boolean
function M.is_dir(filename)
  return M.exists(filename) == "directory"
end

---@return boolean
function M.is_file(filename)
  return M.exists(filename) == "file"
end

function M.create_file(path)
  local p = Plenary_path.new(path)
  if not p:exists() then
    p:touch()
  end
end

function M.create_dir(path)
  local p = Plenary_path.new(path)
  if not p:exists() then
    p:mkdir()
  end
end

function M.system_command(cmds)
  vim.system(cmds, { detach = true }, function(res)
    if res.code ~= 0 then
      vim.schedule(function()
        ---@diagnostic disable-next-line: undefined-field
        M.error("utils", "failed to open Zathura:" .. (res.stderr or ""))
      end)
    end
  end)
end

---@param name string
---@param opts? {group: string}
function M.create_augroup_name(name, opts)
  opts = opts or { group = "PDFview" }
  return vim.api.nvim_create_augroup(opts.group .. name, { clear = true })
end

---@param augroup_name string
function M.clear_autocmd_group(augroup_name)
  pcall(vim.api.nvim_clear_autocmds, { group = augroup_name })
  pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
end

---@param title string
---@param prefix? string
function M.format_title(title, prefix)
  return " " .. (prefix or "PDFview:") .. " " .. title .. " "
end

local function delete_bufnr(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

---@param opts {buf?: integer|integer[], win?: integer|integer[]}
function M.close_win(opts)
  opts = opts or {}

  ---@param val integer|integer[]|nil
  ---@return integer[]
  local function to_list(val)
    if val == nil then
      return {}
    elseif type(val) == "table" then
      return val
    else
      return { val }
    end
  end

  for _, w in ipairs(to_list(opts.win)) do
    if vim.api.nvim_win_is_valid(w) then
      vim.api.nvim_win_close(w, true)
    end
  end

  for _, b in ipairs(to_list(opts.buf)) do
    if vim.api.nvim_buf_is_valid(b) then
      delete_bufnr(b)
    end
  end
end

---@param contents PDFviewBookmarkSaved[]
---@param filename string
function M.save_table_to_file(contents, filename)
  local file = io.open(filename, "w")
  if file then
    file:write "return "
    file:write(tostring(vim.inspect(contents)))
    file:close()
  else
    M.warn("utils", "Failed to save data table to file")
  end
end

---@param str string
---@return string
local rstrip_whitespace = function(str)
  str = string.gsub(str, "%s+$", "")
  return str
end

---@param str string
---@param limit? string|nil
---@return string
local lstrip_whitespace = function(str, limit)
  if limit ~= nil then
    local num_found = 0
    while num_found < limit do
      str = string.gsub(str, "^%s", "")
      num_found = num_found + 1
    end
  else
    str = string.gsub(str, "^%s+", "")
  end
  return str
end

---@param str string
---@return string
function M.strip_whitespace(str)
  if str then
    return rstrip_whitespace(lstrip_whitespace(str))
  end
  return ""
end

local get_hl = function(group)
  return vim.api.nvim_get_hl(0, { name = group })
end

---@return PDFviewBookmarkSaved[]|nil
function M.get_pdf_bookmarks()
  local Config = require "pdfview.config"
  local file_saved = Config.defaults.save
  if not M.is_file(file_saved) then
    M.create_file(file_saved)
  end
  return dofile(file_saved) or {}
end

---@param opts {buffer_line: integer, target_line: integer, total_text_search: integer, idx_text_search: integer}
---@param state PDFviewStateRender
local function __add_text_search_indicator(opts, state)
  local cfg = require("pdfview.config").defaults

  -- stylua: ignore
  local sepFront = (cfg.window.text_search_indicator and cfg.window.text_search_indicator.sep_front) and cfg.window.text_search_indicator.sep_front or ""
  -- stylua: ignore
  local sepBack = (cfg.window.text_search_indicator and cfg.window.text_search_indicator.sep_back) and cfg.window.text_search_indicator.sep_back or ""
  local hl_fg_group = (cfg.window.text_search_indicator and cfg.window.text_search_indicator.hl) or "WarningMsg"
  local hl_fg_attr = (cfg.window.text_search_indicator and cfg.window.text_search_indicator.attr) or "fg"
  -- stylua: ignore
  local icon = (cfg.window.text_search_indicator and cfg.window.text_search_indicator.icon) and cfg.window.text_search_indicator.icon or " "
  local text = string.format(
    "%d/%d %s found | query: %s",
    opts.idx_text_search or 0,
    opts.total_text_search or 0,
    (opts.total_text_search == 1 or opts.total_text_search == 0) and "result" or "results",
    state.search.current_query
  )

  local hl_bg = get_hl(hl_fg_group)[hl_fg_attr]
  local hl_fg = get_hl("Normal")["bg"]

  vim.api.nvim_set_hl(0, "PDFviewStatusSearchSep", { fg = hl_bg, bg = hl_fg })
  vim.api.nvim_set_hl(0, "PDFviewStatusSearchIcon", { fg = hl_fg, bg = hl_bg })
  vim.api.nvim_set_hl(0, "PDFviewStatusSearchNormal", { fg = hl_fg, bg = hl_bg, bold = true })

  local segments = {
    { text = sepFront, hl = "PDFviewStatusSearchSep" },
    { text = icon, hl = "PDFviewStatusSearchIcon" },
    { text = " " .. text, hl = nil },
    { text = sepBack, hl = "PDFviewStatusSearchSep" },
  }

  local full_line = ""
  for _, seg in ipairs(segments) do
    full_line = full_line .. seg.text
  end

  -- Close before respawn the indicator
  if state.win_status_search_indicator and vim.api.nvim_win_is_valid(state.win_status_search_indicator) then
    vim.api.nvim_win_close(state.win_status_search_indicator, true)
  end

  -- no need this?
  -- M.del_namespace(state.buf, state.ns_search_id)
  -- state.ns_search_id = vim.api.nvim_create_namespace "pdfview_status_search_indicator"

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { full_line })

  local ns = vim.api.nvim_create_namespace "pdfview_status_search_indicator"

  local current_col = 0
  for _, seg in ipairs(segments) do
    if seg.hl then
      M.set_extmark(buf, ns, 0, current_col, {
        end_row = 0,
        end_col = current_col + #seg.text,
        hl_group = seg.hl,
      })
    end
    current_col = current_col + #seg.text
  end

  local winnr = vim.api.nvim_get_current_win()

  local height = 1
  local width = vim.fn.strdisplaywidth(full_line)

  local win_width = vim.api.nvim_win_get_width(winnr)

  local padding = 2

  local row = padding
  local col = math.floor((win_width - width) / 2)

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "win",
    win = winnr,
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    focusable = false,
    zindex = 8,
  })

  vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.buf })

  local winhl = "Normal:PDFviewStatusSearchNormal,FloatBorder:Normal,"
  vim.api.nvim_set_option_value("winhighlight", winhl, { win = win, scope = "local" })

  state.win_status_search_indicator = win
end

---@param item PDFviewMatch
---@param state PDFviewStateRender
---@param idx_text_search? integer
---@param total_search_text? integer
function M.__add_buf_highlight(item, state, idx_text_search, total_search_text)
  vim.schedule(function()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_set_current_win(state.win)

      local bufline_count = vim.api.nvim_buf_line_count(state.buf)
      local target_line = math.min(item.line, bufline_count)
      local target_col = math.max((item.col or 1) - 1, 0)

      vim.api.nvim_win_set_cursor(state.win, { target_line, target_col })

      local line_text = vim.api.nvim_buf_get_lines(state.buf, target_line - 1, target_line, false)[1] or ""
      local end_col = #line_text

      if idx_text_search and total_search_text then
        local __opts = {
          buffer_line = bufline_count,
          target_line = target_line,
          idx_text_search = idx_text_search,
          total_text_search = total_search_text,
        }
        __add_text_search_indicator(__opts, state)
      end

      M.del_namespace(state.buf, state.ns_search_id)
      local mark_id = M.set_extmark(state.buf, state.ns_search_id, target_line - 1, target_col, {
        end_row = target_line - 1,
        end_col = end_col,
        hl_group = "Search",
      })

      if mark_id then
        vim.defer_fn(function()
          M.del_extmark(state.buf, state.ns_search_id, mark_id)
        end, 2000)
      end
    end
  end)
end

function M.set_extmark(bufnr, namespace_name, line, col, opts)
  if vim.api.nvim_buf_is_valid(bufnr) then
    local ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace_name, line, col, opts)

    if not ok then
      M.error "failed to create extmark annotation."
      return nil
    end

    return id
  end
end

---@param bufnr integer
---@param ns integer
---@param id integer
function M.del_extmark(bufnr, ns, id)
  if vim.api.nvim_buf_is_valid(bufnr) then
    return pcall(vim.api.nvim_buf_del_extmark, bufnr, ns, id)
  end
end

---@param bufnr integer
---@param ns integer
function M.del_namespace(bufnr, ns)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

return M
