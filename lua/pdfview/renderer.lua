local Config = require "pdfview.config"
local Util = require "pdfview.utils"

local M = {}

-- State to keep track of pages
local state = {
  current_page = 1,
  total_pages = 0,
  pdf_path = "",
  filetype = "pdfview",
  pages = {},
}

---@param page_num number|nil
local function __go_to(page_num)
  if page_num then
    state.current_page = page_num
    M.display_current_page()
    return
  end

  vim.ui.input({
    prompt = "Go to page",
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
    M.display_current_page()
  end)
end

---@param page_num number|nil
local function __open_in_zathura(page_num)
  if Config.defaults.pdf_path then
    state.pdf_path = Config.defaults.pdf_path
  end
  if not page_num then
    page_num = state.current_page
  end

  if not Util.is_file(state.pdf_path) or state.pdf_path == "" then
    return
  end

  local zathura_cmd = { "zathura", "-P", tostring(page_num), state.pdf_path }
  Util.system_cmd(zathura_cmd)
end

local function setup_pdfview_ft_mappings(ctx)
  local bufnr = ctx.buf

  vim.keymap.set("n", Config.defaults.keymaps.go_to_page, __go_to, {
    buf = bufnr,
    desc = "Go to page",
  })

  vim.keymap.set("n", Config.defaults.keymaps.show_page_in_zathura, __open_in_zathura, {
    buf = bufnr,
    desc = "Show page in zathura",
  })

  vim.keymap.set("n", Config.defaults.keymaps.next_page, M.next_page, {
    buf = bufnr,
    desc = "next page",
  })

  vim.keymap.set("n", Config.defaults.keymaps.prev_page, M.previous_page, {
    buf = bufnr,
    desc = "previous page",
  })
end

function M.setup_filetype_mappings(group)
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = state.filetype,
    desc = "CodeCompanion filetype mappings",
    callback = setup_pdfview_ft_mappings,
  })
end

-- Function to display the current page
function M.display_current_page()
  local buf = state.buf

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
  local buf = state.buf
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
  state.pdf_path = pdf_path

  state.pages = M.paginate_text(text)
  state.total_pages = #state.pages
  state.current_page = 1

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
  vim.api.nvim_set_current_buf(buf)
end

-- Function to go to the next page
function M.next_page()
  if state.current_page < state.total_pages then
    state.current_page = state.current_page + 1
    M.display_current_page()
  else
    Util.warn "PDFview: Already at the last page."
  end
end

-- Function to go to the previous page
function M.previous_page()
  if state.current_page > 1 then
    state.current_page = state.current_page - 1
    M.display_current_page()
  else
    Util.warn "PDFview: Already at the first page."
  end
end

function M.get()
  return state
end

return M
