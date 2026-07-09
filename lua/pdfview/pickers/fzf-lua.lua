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
      Util.error "This extension requires ibhagwan/fzf-lua (https://github.com/ibhagwan/fzf-lua)"
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

    local pdf_path = path .. "/" .. sel
    pdf_path = vim.fs.normalize(pdf_path)
    cb(pdf_path)
  end
end

---@param pdf_bookmarks PDFviewBookmarkSaved[]
function Mapping.default_bookmark(pdf_bookmarks, cb)
  return function(selection)
    if not selection then
      return
    end

    local sel = vim.split(selection[1], "·")

    local sel_page_num = Util.strip_whitespace(sel[1])
    local sel_pdf_path = Util.strip_whitespace(sel[2])

    for i, _pdf in pairs(pdf_bookmarks) do
      if _pdf.text_page == sel_page_num and _pdf.text_path == sel_pdf_path then
        return cb(pdf_bookmarks[i])
      end
    end
  end
end

---@param pdf_bookmarks PDFviewBookmarkSaved[]
function Mapping.delete_bookmark(pdf_bookmarks)
  return function(selection)
    if not selection then
      return
    end

    local sel = vim.split(selection[1], "·")

    local sel_page_num = Util.strip_whitespace(sel[1])
    local sel_pdf_path = Util.strip_whitespace(sel[2])
    local file_saved = require("pdfview.config").defaults.save

    for i, _pdf in pairs(pdf_bookmarks) do
      if _pdf.text_page == sel_page_num and _pdf.text_path == sel_pdf_path then
        pdf_bookmarks[i] = nil

        table.sort(pdf_bookmarks, function(a, b)
          return (a.created_at or 0) > (b.created_at or 0)
        end)

        Util.save_table_to_file(pdf_bookmarks, file_saved)
        Util.info(_pdf.text_path .. " removed.")

        -- unplanned: should resume or exit?
        -- FzfLua.actions.resume()
        return
      end
    end
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
    fzf_opts = { ["--header"] = [[^x:delete  ^r:rename]] },
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

  local pdf_bookmarks = Util.get_pdf_bookmarks()
  if not pdf_bookmarks then
    return
  end

  local contents = UtilPicker.bookmark_contents(pdf_bookmarks)
  if Util.is_blank(contents) then
    return
  end

  FzfLua.fzf_exec(contents, {
    no_header = true,
    no_header_i = true,
    fzf_opts = { ["--header"] = [[^x:delete]] },
    winopts = { title = Util.format_title "bookmarks", preview = { hidden = true } },
    actions = {
      ["default"] = Mapping.default_bookmark(pdf_bookmarks, cb),
      ["ctrl-x"] = Mapping.delete_bookmark(pdf_bookmarks),
    },
  })
end

return M
