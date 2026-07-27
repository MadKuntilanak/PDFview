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
  local pdf_bookmark = Util.get_pdf_bookmarks()
  if not pdf_bookmark or Util.is_blank(pdf_bookmark.items) then
    Util.warn "No saved pdf bookmarks found."
    return
  end

  local contents = UtilPicker.bookmark_contents(pdf_bookmark.items)
  if Util.is_blank(contents) then
    return
  end

  vim.ui.select(contents, { prompt = Util.format_title "bookmarks" }, function(selection)
    if not selection then
      return
    end

    local sel = vim.split(selection, "·")
    if not sel then
      return
    end

    local sel_page_num = Util.strip_whitespace(sel[1])
    local sel_pdf_path = Util.strip_whitespace(sel[2])

    for i, bookmark_item in pairs(pdf_bookmark.items) do
      if bookmark_item.text_page == sel_page_num and bookmark_item.text_path == sel_pdf_path then
        local sel_pdf_bookmark = pdf_bookmark.items[i]
        if sel_pdf_bookmark then
          local pdf_path = sel_pdf_bookmark.pdf_path
          local pages = pdf_bookmark.__o[pdf_path]
          if pages then
            sel_pdf_bookmark.pages = pages["pages"]
          end
          return cb(sel_pdf_bookmark)
        end
      end
    end
  end)
end

function M.delete_item_bookmark()
  local pdf_bookmark = Util.get_pdf_bookmarks()
  if not pdf_bookmark or Util.is_blank(pdf_bookmark.items) then
    Util.warn "No saved pdf bookmarks found."
    return
  end

  local contents = UtilPicker.bookmark_contents(pdf_bookmark.items)
  if Util.is_blank(contents) then
    return
  end

  vim.ui.select(contents, { prompt = Util.format_title "delete bookmarks" }, function(selection)
    if not selection then
      return
    end

    local sel = vim.split(selection, "·")
    if not sel then
      return
    end

    local sel_page_num = Util.strip_whitespace(sel[1])
    local sel_pdf_path = Util.strip_whitespace(sel[2])
    local file_saved = require("pdfview.config").defaults.save

    for i, bookmark_item in pairs(pdf_bookmark.items) do
      if bookmark_item.text_page == sel_page_num and bookmark_item.text_path == sel_pdf_path then
        table.remove(pdf_bookmark.items, i)

        table.sort(pdf_bookmark.items, function(a, b)
          return (a.created_at and a.created_at or 0) > (b.created_at and b.created_at or 0)
        end)

        Util.save_table_to_file(pdf_bookmark, file_saved)

        local filename = vim.fs.basename(bookmark_item.text_path)
        Util.info(string.format("Removed bookmark page %s in `%s`.", bookmark_item.text_page, filename))
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
