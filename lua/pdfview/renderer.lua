local Config = require "pdfview.config"
local Util = require "pdfview.utils"

local M = {}

-- State to keep track of pages
---@type PDFviewStateRender
local state = {
  current_page = 1,
  total_pages = 0,
  pdf_path = "",
  filetype = "pdfview",
  page_offset = 0,
  buf = nil,
  ns_id = nil,
  ns_search_id = nil,
  pages = {},
}

-- Function to display the current page
function M.display_current_page()
  local buf = state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Set buffer to modifiable before making changes
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  -- Clear existing buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

  -- Get the lines for the current page
  local page_lines = state.pages[state.current_page]

  -- Set the lines in the buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, page_lines)

  -- Set buffer back to non-modifiable
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  -- Update statusline or virtual text with page information
  M.update_page_info()
end

-- Function to update page information
function M.update_page_info()
  if Config.defaults.pdf_path then
    state.pdf_path = Config.defaults.pdf_path
  end

  local buf = state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local real_page = state.current_page + (state.page_offset or 0)
  local real_total = state.total_pages + (state.page_offset or 0)
  local page_info = string.format("Page %d/%d", real_page, real_total)

  vim.api.nvim_buf_clear_namespace(buf, state.ns_id, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, state.ns_id, 0, 0, {
    virt_text = { { page_info, "Comment" } },
    virt_text_pos = "right_align",
  })
end

-- Function to split text into pages
function M.paginate_text(text)
  text = text:gsub("\f%s*$", "")

  local raw_pages = vim.split(text, "\f", { plain = true })
  local pages = {}
  for _, page_text in ipairs(raw_pages) do
    table.insert(pages, vim.split(page_text, "\n"))
  end
  return pages
end

-- Function to initialize the buffer and display the first page
function M.display_text(text, start_page, pdf_path)
  if Config.defaults.pdf_path then
    state.pdf_path = pdf_path
  end

  state.pages = M.paginate_text(text)
  state.total_pages = #state.pages

  if start_page then
    state.current_page = start_page
  else
    state.current_page = 1
  end

  state.page_offset = (start_page or 1) - 1

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
  end

  local buf = state.buf

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", state.filetype, { buf = buf })

  state.ns_id = vim.api.nvim_create_namespace "PDFview"

  M.display_current_page()

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_set_current_buf(state.buf)
  end
end

-- Function to go to the next page
function M.next_page()
  if state.current_page < state.total_pages then
    state.current_page = state.current_page + 1
    M.display_current_page()
  else
    Util.warn("renderer", "Already at the last page.")
  end
end

-- Function to go to the previous page
function M.previous_page()
  if state.current_page > 1 then
    state.current_page = state.current_page - 1
    M.display_current_page()
  else
    Util.warn("renderer", "Already at the firts page.")
  end
end

function M.get()
  return state
end

return M
