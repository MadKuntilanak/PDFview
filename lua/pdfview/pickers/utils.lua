local Util = require "pdfview.utils"

local M = {}

---@param pdf_bookmarks PDFviewBookmarkSavedData
local padding = function(pdf_bookmarks)
  local _pad = 0
  for _, x in ipairs(pdf_bookmarks) do
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

---@param pdf_bookmarks_data PDFviewBookmarkSavedData
---@return string[]
function M.bookmark_contents(pdf_bookmarks_data)
  if not pdf_bookmarks_data then
    return {}
  end
  if Util.is_blank(pdf_bookmarks_data) then
    Util.warn "No saved PDF bookmarks found. Please create one first."
    return {}
  end

  local _pad = padding(pdf_bookmarks_data)

  local contents = {}
  for _, _pdf in pairs(pdf_bookmarks_data) do
    contents[#contents + 1] = string.format("%-" .. _pad .. "s · %s", _pdf.text_page, _pdf.text_path)
  end
  return contents
end

---@alias PDFviewJumpL { contents: table, hval: {idx: integer, text_line: string, page: integer, text: string}[] } }

---@param state PDFviewStateRender
---@return PDFviewJumpL|nil
function M.get_jumplist(state)
  if not state.history then
    return nil
  end

  local hist = state.history
  if not hist or #hist.list == 0 then
    Util.warn "no page history yet"
    return nil
  end

  local contents = {}
  local hval = {}

  local _pad = 0
  for _, x in ipairs(hist.list) do
    local page_str = string.format("[p.%d]", x.page)
    if _pad < #page_str then
      _pad = #page_str
    end
  end

  for idx, _h in ipairs(hist.list) do
    local page_str = string.format("[p.%d]", _h.page)
    local text_line = string.format("%-" .. _pad .. "s %s", page_str, _h.text ~= "" and _h.text or "(no preview)")
    contents[#contents + 1] = text_line
    hval[#hval + 1] = {
      idx = idx,
      text_line = text_line,
      page = _h.page,
      text = _h.text,
    }
  end

  return { contents = contents, hval = hval }
end

---@param state PDFviewStateRender
---@return {contents: table, seen: table<string, PDFviewMatch>}|nil
function M.search_cache(state)
  if not state.search or not state.search.cache or not state.search.current_query then
    return nil
  end

  local items = state.search.cache[state.search.current_query]
  local contents = {}
  local seen = {}
  for _, x in pairs(items) do
    contents[#contents + 1] = x.text_line
    seen[x.text_line] = x
  end

  return {
    contents = contents,
    seen = seen,
  }
end

return M
