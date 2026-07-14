local Util = require "pdfview.utils"

local parser = require "pdfview.parser"
local renderer = require "pdfview.renderer"

local M = {}

---@param pdf_path string
---@param query string
---@param state? PDFviewStateRender
---@param opts? {case_sensitive: boolean, pages:table}
---@return PDFviewMatch[]
function M.find_matches(pdf_path, query, state, opts)
  opts = opts or {}
  state = state or renderer.get()

  local pages = state.pages
  if Util.is_blank(pages) then
    local full_text = parser.extract_text(pdf_path)
    if not full_text then
      return {}
    end
    pages = renderer.paginate_text(full_text)
  end

  local matches = {}
  local pattern = opts.case_sensitive and query or query:lower()

  for page_num, lines in ipairs(pages) do
    for line_num, line in ipairs(lines) do
      local haystack = opts.case_sensitive and line or line:lower()
      local col = haystack:find(pattern, 1, true)
      if col then
        table.insert(matches, {
          page = page_num,
          line = line_num,
          col = col,
          text = vim.trim(line),
        })
      end
    end
  end
  return matches
end

return M
