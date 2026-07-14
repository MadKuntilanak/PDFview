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
  Config.defaults.save = Config.defaults.save .. "/pdfview.lua"

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
  local pdf_bookmarks = Util.get_pdf_bookmarks()
  if not pdf_bookmarks then
    return
  end

  local opts = pdf_bookmarks[1]
  Config.defaults.pdf_path = opts.pdf_path
  M.open(opts.pdf_path, opts)
  ensure_callback(opts.pdf_path)
end

function M.history()
  Util.not_implemented_yet()
end

function M.menu()
  local ui = require "pdfview.ui"
  ui.call("menu", Config.defaults)
end

---@param page_num number|nil
---@param state? PDFviewStateRender
---@param notify? boolean
function M.go_to(page_num, state, notify)
  state = state or renderer.get()
  notify = notify or false

  if page_num then
    state.current_page = page_num
    renderer.display_current_page()
    if notify then
      Util.info(string.format("Go to page: %d", state.current_page))
    end
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
      Util.warn("go_to", "not a number `" .. input .. "`")
      return
    end

    state.current_page = num

    if notify then
      Util.info(string.format("Go to page: %d", state.current_page))
    end
    renderer.display_current_page()
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
---@param opts? table
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

  last_open_pdf = opts.pdf_path

  local text = parser.extract_text(opts.pdf_path)
  if text then
    renderer.display_text(text, opts.last_page)
    local pdffile = vim.fn.fnamemodify(opts.pdf_path, ":~")
    Util.info("Loaded PDF: `" .. pdffile .. "`")
  end
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
    Util.warn("no matches for '" .. query .. "'")
    return
  end

  if not state.win then
    state.win = vim.api.nvim_get_current_win()
  end

  state.search = state.search or { cache = {} }
  state.search.cache[query] = matches
  state.search.current_query = query
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
