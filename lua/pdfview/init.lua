local Config = require "pdfview.config"
local Util = require "pdfview.utils"

local parser = require "pdfview.parser"
local renderer = require "pdfview.renderer"
local search = require "pdfview.search"
local picker = require "pdfview.pickers"

local M = {}

---@param opts PDFviewCfg
function M.setup(opts)
  Config.update_settings(opts)

  Config.defaults.group = "PDFview"
  local save_folder = Config.defaults.save .. "/pdfview"

  if not Util.is_dir(save_folder) then
    Util.create_dir(save_folder)
  end

  Config.defaults.save = save_folder .. "/pdfview.lua"
  Config.defaults.save_last_open = save_folder .. "/pdfview_lastopen.lua"

  Util.clear_autocmd_group(Config.defaults.group)
  local group = vim.api.nvim_create_augroup(Config.defaults.group, { clear = true })

  local keymaps = require "pdfview.keymaps"
  keymaps.setup_filetype_mappings(group, renderer.get())
end

---@param pdf_path string
local function ensure_callback(pdf_path)
  if Config.defaults.open and Config.defaults.open.cb then
    if type(Config.defaults.open.cb) ~= "function" then
      return
    end
    Config.defaults.open.cb(pdf_path)
  end
end

function M.select_file_pdf()
  local path = Config.defaults.path
  if not Util.is_dir(path) then
    return
  end

  picker.select(Config.defaults.picker or "default", "files", path, function(pdf_path)
    if not Util.is_file(pdf_path) then
      Util.warn("PDF path doesn't exist: `" .. pdf_path .. "`.")
      return
    end

    Config.defaults.pdf_path = pdf_path
    M.open(pdf_path)
    ensure_callback(pdf_path)
  end)
end

function M.select_bookmark()
  local file_saved = Config.defaults.save
  if not Util.is_file(file_saved) then
    Util.warn "Bookmark save file not found. Please create one first."
    return
  end

  picker.select(Config.defaults.picker or "default", "bookmark", file_saved, function(opts)
    Config.defaults.pdf_path = opts.pdf_path
    M.open(opts.pdf_path, opts)
    ensure_callback(opts.pdf_path)
  end)
end

function M.select_text_search()
  local path = Config.defaults.path
  if not Util.is_dir(path) then
    return
  end

  picker.select(Config.defaults.picker or "default", "search", path, nil)
end

function M.open_from_last_bookmark()
  local pdf_bookmark = Util.get_pdf_bookmarks()
  if not pdf_bookmark or Util.is_blank(pdf_bookmark.items) then
    Util.warn "No saved pdf bookmarks found."
    return
  end

  local opts = pdf_bookmark.items[1]
  if not opts then
    return
  end

  local pdf_path = opts.pdf_path
  Config.defaults.pdf_path = pdf_path
  local pages = pdf_bookmark.__o[pdf_path]
  if pages then
    opts.pages = pages["pages"]
  end

  M.open(opts.pdf_path, opts)
  ensure_callback(opts.pdf_path)
end

function M.open_last()
  local file_saved = Config.defaults.save_last_open
  if not Util.is_file(file_saved) then
    Util.warn "No saved last opened file was found. Please open a PDF first."
    return
  end

  local ok, last_open = pcall(dofile, file_saved)

  if not ok or type(last_open) ~= "table" or Util.is_blank(last_open.pdf_path) then
    Util.warn "Failed to read last opened PDF data."
    return
  end

  Config.defaults.pdf_path = last_open.pdf_path
  M.open(last_open.pdf_path, { last_page = last_open.last_page, pages = last_open.pages })

  local state = renderer.get()
  state.pages = last_open.pages or {}

  ensure_callback(last_open.pdf_path)
end

function M.menu()
  local ui = require "pdfview.ui"
  ui.call("menu", Config.defaults)
end

---@param state PDFviewStateRender
local function capture_context(state)
  local win = state.win or vim.api.nvim_get_current_win()
  local ok, pos = pcall(vim.api.nvim_win_get_cursor, win)
  local line, col = 1, 0
  if ok then
    line, col = pos[1], pos[2]
  end

  local text = ""
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    local ok2, lines = pcall(vim.api.nvim_buf_get_lines, state.buf, line - 1, line, false)
    if ok2 and lines[1] then
      text = vim.trim(lines[1])
    end
  end

  return { line = line, col = col, text = text, created_at = os.time() }
end

---@param state PDFviewStateRender
---@param entry {page: integer, line: integer, col: integer}
local function restore_cursor(state, entry)
  vim.schedule(function()
    local win = state.win or vim.api.nvim_get_current_win()
    if not win or not vim.api.nvim_win_is_valid(win) then
      return
    end

    local buf = vim.api.nvim_win_get_buf(win)
    local line_count = vim.api.nvim_buf_line_count(buf)
    local target_line = math.min(math.max(entry.line or 1, 1), line_count)

    local line_text = vim.api.nvim_buf_get_lines(buf, target_line - 1, target_line, false)[1] or ""
    local target_col = math.min(entry.col or 0, #line_text)

    pcall(vim.api.nvim_win_set_cursor, win, { target_line, target_col })
  end)
end

---@param state PDFviewStateRender
---@param from_page integer
---@param to_page integer
local function record_jump(state, from_page, to_page)
  state.history = state.history or { list = {}, pointer = 0 }
  local hist = state.history

  if hist.pointer < #hist.list then
    for i = #hist.list, hist.pointer + 1, -1 do
      table.remove(hist.list, i)
    end
  end

  local from_entry = capture_context(state)
  from_entry.page = from_page

  if not hist.list[#hist.list] or hist.list[#hist.list].page ~= from_page then
    table.insert(hist.list, from_entry)
  end

  local to_entry = { page = to_page, line = 1, col = 0, text = "", created_at = os.time() }
  if not hist.list[#hist.list] or hist.list[#hist.list].page ~= to_page then
    table.insert(hist.list, to_entry)
  end

  hist.pointer = #hist.list

  local max_hist = Config.defaults.max_jumplist_page or 10
  while #hist.list > max_hist do
    table.remove(hist.list, 1)
    hist.pointer = math.max(1, hist.pointer - 1)
  end
end

function M.select_jumplist()
  local state = renderer.get()
  state.history = state.history or { list = {}, pointer = 0 }
  local hist = state.history

  if #hist.list == 0 then
    Util.warn "no page history yet"
    return
  end

  picker.select(Config.defaults.picker or "default", "jumplist", nil, function(opts)
    if not opts then
      return
    end

    hist.pointer = opts.idx
    local entry = hist.list[hist.pointer]

    M.go_to(entry.page, state, true)
    restore_cursor(state, entry)
  end)
end

---@param step integer
---@param state? PDFviewStateRender
function M.jumplist(step, state)
  state = state or renderer.get()
  state.history = state.history or { list = {}, pointer = 0 }
  local hist = state.history

  if #hist.list == 0 then
    Util.warn "no page history yet"
    return
  end

  local new_pointer = hist.pointer + step
  if new_pointer < 1 or new_pointer > #hist.list then
    Util.warn(step < 0 and "already at oldest position" or "already at newest position")
    return
  end

  hist.pointer = new_pointer
  local entry = hist.list[hist.pointer]

  M.go_to(entry.page, state, true)
  restore_cursor(state, entry)
end

---@param page_num number|nil
---@param state? PDFviewStateRender
---@param skip_record? boolean
---@param notify? boolean
function M.go_to(page_num, state, skip_record, notify)
  state = state or renderer.get()
  notify = notify or false
  skip_record = skip_record or false

  ---@param num integer
  local function jump_to_page(num)
    if num < 1 or num > state.total_pages then
      Util.warn(string.format("page %d out of range (1-%d)", num, state.total_pages))
      return
    end

    if not skip_record then
      record_jump(state, state.current_page, num)
    end

    state.current_page = num
    renderer.display_current_page()

    if notify then
      Util.info(string.format("Go to page: %d", state.current_page))
    end
  end

  if page_num then
    jump_to_page(page_num)
    return
  end

  vim.ui.input({
    prompt = "Go to page: ",
  }, function(input)
    if not input then
      return
    end

    local num = tonumber(input)
    if not num then
      Util.warn("go_to", "Not a number `" .. input .. "`")
      return
    end

    jump_to_page(num)
  end)
end

---@param page_num number|nil
---@param state? PDFviewStateRender
function M.open_in_zathura(page_num, state)
  state = state or renderer.get()

  if not page_num then
    page_num = state.current_page
  end

  if not Util.is_file(state.pdf_path) or state.pdf_path == "" then
    return
  end

  local zathura_cmd = { "zathura", "-P", tostring(page_num), state.pdf_path }
  Util.system_command(zathura_cmd)
end

local last_open_pdf

-- Function to open the full PDF text (runs when PDF is selected)
---@param pdf_path string
---@param opts? {pdf_path: string, last_page: integer, pages: table}
function M.open(pdf_path, opts)
  opts = opts or {}

  if not opts.pdf_path then
    opts.pdf_path = pdf_path
  end

  if not opts.last_page then
    opts.last_page = 1
  end

  if last_open_pdf and last_open_pdf == opts.pdf_path and vim.bo.filetype == "pdfview" then
    M.go_to(opts.last_page)
    return
  end

  if not opts.pages then
    local get_o_pdf_path = renderer.get().o[pdf_path]
    if get_o_pdf_path then
      opts.pages = get_o_pdf_path["pages"]
    end
  end

  local loaded = false

  if opts.pages and not Util.is_blank(opts.pages) then
    renderer.display_text(nil, opts.last_page, opts.pages)
    loaded = true
  else
    local text = parser.extract_text(opts.pdf_path)
    if text then
      renderer.display_text(text, opts.last_page)
      loaded = true
    end
  end

  if not loaded then
    return
  end

  last_open_pdf = opts.pdf_path

  Util.info(("Loaded PDF: `%s`"):format(vim.fn.fnamemodify(opts.pdf_path, ":~")))
end

---@param pdf_path string
---@param query string
---@param state? PDFviewStateRender
local function search_to(pdf_path, query, state)
  state = state or renderer.get()

  local matches
  if state.search and state.search.cache and state.search.cache[query] then
    matches = state.search.cache[query]
  else
    matches = search.find_matches(pdf_path, query, state)
  end

  if #matches == 0 then
    Util.warn("No matches for '" .. query .. "'")
    return
  end

  if not state.win then
    state.win = vim.api.nvim_get_current_win()
  end

  state.search = state.search or { cache = {} }
  state.search.cache[query] = matches
  state.search.current_query = query
  state.search.current_idx = 0
  state.ns_search_id = vim.api.nvim_create_namespace "pdfview-search"

  Util.info(string.format("Found `%d %s` for query `%s`", #matches, (#matches == 1) and "match" or "matches", query))

  -- debug: test open item matches in quickfix..
  -- local qf_items = {}
  -- for _, m in ipairs(matches) do
  --   table.insert(qf_items, {
  --     filename = m.filename,
  --     lnum = m.page,
  --     col = m.col,
  --     text = m.text_line,
  --     page = m.line,
  --   })
  -- end
  -- vim.fn.setqflist({}, " ", { title = "PDFview: " .. query, items = qf_items })
  -- vim.cmd "copen"
end

---@param pdf_path? string
---@param query? string
function M.text_search(pdf_path, query)
  if pdf_path and query then
    search_to(pdf_path, query)
  end

  vim.ui.input({
    prompt = "Text Search: ",
  }, function(q)
    if not q then
      return
    end

    local state = renderer.get()
    if state and state.pdf_path then
      search_to(state.pdf_path, q)
    end
  end)
end

-- Function to extract and display the first page (used for preview)
---@param pdf_path string
---@return string
function M.preview_first_page(pdf_path)
  local first_page_text = parser.extract_text(pdf_path, 1, 1)
  if first_page_text then
    return first_page_text
  else
    return "Could not extract text from the first page of the PDF."
  end
end

return M
