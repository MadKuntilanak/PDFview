local Util = require "pdfview.utils"
local UtilPicker = require "pdfview.pickers.utils"

local M = {}

local function list_files(path)
  local cmd = UtilPicker.find_command(path)
  local files = vim.fn.systemlist(cmd)
  return files
end

---@param path string
---@param cb function
function M.files(path, cb)
  local files = list_files(path)
  vim.ui.select(files, { prompt = Util.format_title "pdf files" }, function(file)
    if not file then
      return
    end

    local pdf_path = vim.fs.normalize(file)
    cb(pdf_path)
  end)
end

---@param path string
---@param cb function
function M.bookmark(path, cb)
  local pdf_bookmarks = Util.get_pdf_bookmarks()
  if not pdf_bookmarks then
    return
  end

  local contents = UtilPicker.bookmark_contents(pdf_bookmarks)
  if Util.is_blank(contents) then
    return
  end

  vim.ui.select(contents, { prompt = Util.format_title "bookmarks" }, function(selection)
    if not selection then
      return
    end

    local sel = vim.split(selection, "·")

    local sel_page_num = Util.strip_whitespace(sel[1])
    local sel_pdf_path = Util.strip_whitespace(sel[2])

    for i, _pdf in pairs(pdf_bookmarks) do
      if _pdf.text_page == sel_page_num and _pdf.text_path == sel_pdf_path then
        return cb(pdf_bookmarks[i])
      end
    end
  end)
end

function M.delete_item_bookmark()
  local pdf_bookmarks = Util.get_pdf_bookmarks()
  if not pdf_bookmarks then
    return
  end

  local contents = UtilPicker.bookmark_contents(pdf_bookmarks)
  if Util.is_blank(contents) then
    return
  end

  vim.ui.select(contents, { prompt = Util.format_title "delete bookmarks" }, function(selection)
    if not selection then
      return
    end

    local sel = vim.split(selection, "·")

    local sel_page_num = Util.strip_whitespace(sel[1])
    local sel_pdf_path = Util.strip_whitespace(sel[2])
    local file_saved = require("pdfview.config").defaults.save

    for i, _pdf in pairs(pdf_bookmarks) do
      if _pdf.text_page == sel_page_num and _pdf.text_path == sel_pdf_path then
        table.remove(pdf_bookmarks, i)

        table.sort(pdf_bookmarks, function(a, b)
          return (a.created_at and a.created_at or 0) > (b.created_at and b.created_at or 0)
        end)

        Util.save_table_to_file(pdf_bookmarks, file_saved)
        Util.info(_pdf.text_path .. " removed.")
        return
      end
    end
  end)
end

function M.search()
  local renderer = require "pdfview.renderer"
  local state = renderer.get()

  local data = UtilPicker.search_cache(state)
  if not data then
    Util.warn("picker", "No active search")
    return
  end

  local contents = data.contents
  local seen = data.seen

  vim.ui.select(
    contents,
    { prompt = Util.format_title "<query:" .. state.search.current_query .. ">" },
    function(selection)
      if not selection then
        return
      end

      local sel = selection
      local item = seen[vim.trim(sel)]
      if not item then
        return
      end

      require("pdfview").go_to(item.page, state, true)
      Util.__add_buf_highlight(item, state)
    end
  )
end

return M
