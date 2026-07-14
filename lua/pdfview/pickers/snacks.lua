local snacks = require "snacks"

local Util = require "pdfview.utils"
local UtilPicker = require "pdfview.pickers.utils"

local M = {}

-- local function pdf_previewer(ctx)
--   local item = ctx.item
--   if not item or not item.file then
--     return
--   end
--   -- local text = Parser.extract_text(item.file, 1, 1) -- preview halaman pertama aja
--
--   local text = require("pdfview").preview_first_page(item.file)
--   local lines = vim.split(text or "", "\n")
--   ctx.preview:set_lines(lines)
--   ctx.preview:set_title(vim.fn.fnamemodify(item.file, ":t"))
-- end

local Mapping = {}

---@param pdf_bookmarks PDFviewBookmarkSaved[]
---@param cb function
function Mapping.default_bookmark(pdf_bookmarks, cb, selection)
  if not selection then
    return
  end

  -- local sel = vim.split(selection[1], "·")
  local sel = selection

  local sel_page_num = Util.strip_whitespace(sel[1])
  local sel_pdf_path = Util.strip_whitespace(sel[2])

  for i, _pdf in pairs(pdf_bookmarks) do
    if _pdf.text_page == sel_page_num and _pdf.text_path == sel_pdf_path then
      return cb(pdf_bookmarks[i])
    end
  end
end

---@param pdf_bookmarks PDFviewBookmarkSaved[]
---@param selection string
function Mapping.delete_bookmark(pdf_bookmarks, selection)
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
end

---@param state PDFviewStateRender
---@param seen table<string, PDFviewMatch>
function Mapping.search(state, seen, selection)
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

---@return boolean
function M.is_available()
  return (pcall(require, "snacks"))
end

---@param path string
---@param cb function
function M.files(path, cb)
  snacks.picker.pick {
    source = "files",
    cwd = path,
    title = Util.format_title "pdf files",
    ft = "pdf",
    -- preview = pdf_previewer, -- use the default previewer from Snacks
    confirm = function(picker, item)
      picker:close()
      if item then
        cb(path .. "/" .. item.file)
      end
    end,
  }
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

  local items = {}
  for i, line in ipairs(contents) do
    table.insert(items, { idx = i, text = line })
  end

  snacks.picker.pick {
    title = Util.format_title "bookmarks",
    items = items,
    layout = { preset = "select" },
    format = function(item)
      return { { item.text } }
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        Mapping.default_bookmark(pdf_bookmarks, cb, item.text)
      end
    end,
    actions = {
      delete_bookmark = function(picker, item)
        if not item then
          return
        end
        Mapping.delete_bookmark(pdf_bookmarks, item.text)
        picker:close()
        vim.schedule(function()
          M.bookmark(path, cb)
        end)
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-x>"] = { "delete_bookmark", mode = { "n", "i" } },
        },
      },
    },
  }
end

function M.search()
  local renderer = require "pdfview.renderer"
  local state = renderer.get()

  local data = UtilPicker.search_cache(state)
  if not data then
    Util.warn("picker.fzf-lua", "No active search")
    return
  end

  local contents = data.contents
  local seen = data.seen

  local items = {}
  for i, line in ipairs(contents) do
    table.insert(items, { idx = i, text = line })
  end

  snacks.picker.pick {
    title = Util.format_title "<query:" .. state.search.current_query .. ">",
    items = items,
    layout = { preset = "select" },
    format = function(item)
      return { { item.text } }
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        Mapping.search(state, seen, item.text)
      end
    end,
  }
end

return M
