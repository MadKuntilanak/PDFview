local Config = require "pdfview.config"
local Util = require "pdfview.utils"

local parser = require "pdfview.parser"
local renderer = require "pdfview.renderer"

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

local p

local function load_picker()
  if not p then
    p = require "pdfview.pickers"
    return p
  end

  return p
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

  p = load_picker()
  p.select(Config.defaults.picker or "default", "files", path, function(pdf_path)
    if not Util.is_file(pdf_path) then
      Util.warn("PDF path doesn't exist: `" .. pdf_path .. "`.")
      return
    end

    Config.defaults.pdf_path = pdf_path
    M.open(pdf_path)
    ensure_callback(pdf_path)
  end)
end

function M.bookmark()
  local file_saved = Config.defaults.save
  if not Util.is_file(file_saved) then
    Util.warn "Bookmark save file not found. Please create one first."
    return
  end

  p = load_picker()
  p.select(Config.defaults.picker or "default", "bookmark", file_saved, function(opts)
    Config.defaults.pdf_path = opts.pdf_path
    M.open(opts.pdf_path, opts)
    ensure_callback(opts.pdf_path)
  end)
end

function M.last_bookmark()
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
function M.go_to(page_num, state)
  state = state or renderer.get()

  if page_num then
    state.current_page = page_num
    renderer.display_current_page()
    Util.info(string.format("Go to page: %d", state.current_page))
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
      return
    end

    state.current_page = num

    Util.info(string.format("Go to page: %d", state.current_page))
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

  if last_open_pdf and last_open_pdf == opts.pdf_path then
    M.go_to(opts.last_page)
    return
  end

  last_open_pdf = opts.pdf_path

  local text = parser.extract_text(opts.pdf_path)
  if text then
    renderer.display_text(text, opts.last_page)
  end
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
