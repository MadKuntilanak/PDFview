local Util = require "pdfview.utils"

local M = {}

---@param pdf_bookmarks PDFviewBookmarkSaved[]
local padding = function(pdf_bookmarks)
  local _pad = 0
  for _, x in pairs(pdf_bookmarks) do
    if _pad < #x.text_page then
      _pad = #x.text_page
    end
  end
  return _pad
end

---@param path string
---@return string[]
function M.find_command(path)
  return { "find", path or ".", "-type", "f", "-name", "*.pdf" }
end

---@param pdf_bookmarks PDFviewBookmarkSaved[]
---@return string[]
function M.bookmark_contents(pdf_bookmarks)
  if not pdf_bookmarks then
    return {}
  end
  if Util.is_blank(pdf_bookmarks) then
    Util.warn "No saved PDF bookmarks found. Please create one first."
    return {}
  end

  local _pad = padding(pdf_bookmarks)

  local contents = {}
  for _, _pdf in pairs(pdf_bookmarks) do
    contents[#contents + 1] = string.format("%-" .. _pad .. "s · %s", _pdf.text_page, _pdf.text_path)
  end
  return contents
end

return M
