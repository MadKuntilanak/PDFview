local Parser = require "pdfview.parser"
local M = {}

-- Split full pdftotext output into pages (pdftotext inserts \f between pages)
---@param full_text string
local function split_pages(full_text)
  local pages = {}
  for page in (full_text .. "\f"):gmatch "(.-)\f" do
    table.insert(pages, page)
  end
  return pages
end

---@param pdf_path string
---@param query string
---@param opts? {case_sensitive: boolean, pages:table}
---@return PDFviewMatch[]
function M.find_matches(pdf_path, query, opts)
  opts = opts or {}
  local full_text = Parser.extract_text(pdf_path) -- no start/end = whole doc
  if not full_text then
    return {}
  end

  local pages = split_pages(full_text)
  local matches = {}
  local pattern = opts.case_sensitive and query or query:lower()

  for page_num, page_text in ipairs(pages) do
    local line_num = 0
    for line in (page_text .. "\n"):gmatch "(.-)\n" do
      line_num = line_num + 1
      local haystack = opts.case_sensitive and line or line:lower()
      local col = haystack:find(pattern, 1, true) -- plain-text find
      if col then
        local txt_trim = vim.trim(line)
        table.insert(matches, {
          filename = pdf_path,
          page = page_num,
          line = line_num,
          col = col,
          text = txt_trim,
          text_line = string.format("[p.%d] %s", page_num, txt_trim),
        })
      end
    end
  end
  return matches
end

return M
