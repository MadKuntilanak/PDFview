local Util = require "pdfview.utils"
local UtilPicker = require "pdfview.pickers.utils"

local M = {}

local loaded = false
local FzfLua

local silent_notify = false

local function setup_fzflua()
  if loaded then
    return FzfLua
  end

  local ok, _ = pcall(require, "fzf-lua")
  if not ok then
    if not silent_notify then
      Util.error("fzf-lua", "This extension requires ibhagwan/fzf-lua (https://github.com/ibhagwan/fzf-lua)")
      silent_notify = true
      return
    end
    return
  end

  FzfLua = require "fzf-lua"
  loaded = true

  return FzfLua
end

local Mapping = {}

---@param path string
---@param cb function
function Mapping.default(path, cb)
  return function(selection)
    if not selection then
      return
    end

    local sel = selection[1]
    if not sel then
      return
    end

    local pdf_path = path .. "/" .. sel
    pdf_path = vim.fs.normalize(pdf_path)
    cb(pdf_path)
  end
end

---@param pdf_bookmark PDFviewBookmarkSaved
---@param cb function
function Mapping.default_bookmark(pdf_bookmark, cb)
  return function(selection)
    if not selection then
      return
    end

    local sel = vim.split(selection[1], "·")
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
  end
end

---@param pdf_bookmark PDFviewBookmarkSaved
function Mapping.delete_bookmark(pdf_bookmark)
  return function(selection)
    if not selection then
      return
    end

    local sel = vim.split(selection[1], "·")
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

        -- unplanned: should resume or exit?
        -- FzfLua.actions.resume()
        return
      end
    end
  end
end

---@param state PDFviewStateRender
---@param seen table<string, PDFviewMatch>
function Mapping.search(state, seen)
  return function(selection)
    if not selection then
      return
    end

    local sel = selection[1]
    if not sel then
      return
    end

    local item = seen[vim.trim(sel)]
    if not item then
      return
    end

    require("pdfview").go_to(item.page, state, true)
    Util.__add_buf_highlight(item, state)
  end
end

---@return boolean
function M.is_available()
  return (pcall(require, "fzf-lua"))
end

---@param path string
---@param cb function
function M.files(path, cb)
  setup_fzflua()

  if not loaded then
    return
  end

  FzfLua.files {
    cwd = path,
    no_header = true,
    no_header_i = true,
    -- fzf_opts = { ["--header"] = [[^x:delete  ^r:rename]] },
    winopts = { title = Util.format_title "pdf files", preview = { hidden = false } },
    actions = {
      ["default"] = Mapping.default(path, cb),
    },
  }
end

---@param path string
---@param cb function
function M.bookmark(path, cb)
  setup_fzflua()

  if not loaded then
    return
  end

  local pdf_bookmark = Util.get_pdf_bookmarks()
  if not pdf_bookmark or Util.is_blank(pdf_bookmark.items) then
    Util.warn "No saved pdf bookmarks found."
    return
  end

  local contents = UtilPicker.bookmark_contents(pdf_bookmark.items)
  if Util.is_blank(contents) then
    return
  end

  FzfLua.fzf_exec(contents, {
    no_header = true,
    no_header_i = true,
    fzf_opts = { ["--header"] = [[<C-x> delete]] },
    winopts = { title = Util.format_title "bookmarks", preview = { hidden = true } },
    actions = {
      ["default"] = Mapping.default_bookmark(pdf_bookmark, cb),
      ["ctrl-x"] = Mapping.delete_bookmark(pdf_bookmark),
    },
  })
end

function M.search()
  setup_fzflua()

  local renderer = require "pdfview.renderer"
  local state = renderer.get()

  local data = UtilPicker.search_cache(state)
  if not data then
    Util.warn("picker.fzf-lua", "No active search")
    return
  end

  local contents = data.contents
  local seen = data.seen

  FzfLua.fzf_exec(contents, {
    no_header = true,
    no_header_i = true,
    fzf_opts = { ["--header"] = [[<C-x>:delete]] },
    winopts = { title = Util.format_title "<query:" .. state.search.current_query .. ">", preview = { hidden = true } },
    actions = {
      ["default"] = Mapping.search(state, seen),
    },
  })
end

return M
