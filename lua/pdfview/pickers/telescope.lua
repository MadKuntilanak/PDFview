local telescope = require "telescope.builtin"
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local previewers = require "telescope.previewers"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local Util = require "pdfview.utils"
local UtilPicker = require "pdfview.pickers.utils"

local M = {}

-- Custom previewer for Telescope to show the first page
local pdf_previewer = previewers.new_buffer_previewer {
  define_preview = function(self, entry)
    local pdf_path = entry.path
    local preview_text = require("pdfview").preview_first_page(pdf_path)
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(preview_text, "\n"))
  end,
}

local Mapping = {}

---@param pdf_bookmark PDFviewBookmarkSaved
---@param cb function
---@param entry string
function Mapping.default_bookmark(pdf_bookmark, cb, entry)
  if not entry then
    return
  end

  local sel = vim.split(entry, "·")
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

---@param pdf_bookmark PDFviewBookmarkSaved
---@param entry string
function Mapping.delete_bookmark_entry(pdf_bookmark, entry)
  if not entry then
    return
  end
  local sel = vim.split(entry, "·")
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
end

---@param state PDFviewStateRender
---@param seen table<string, PDFviewMatch>
---@param entry string
function Mapping.search(state, seen, entry)
  if not entry then
    return
  end

  local item = seen[vim.trim(entry)]
  if not item then
    return
  end

  require("pdfview").go_to(item.page, state, true)
  Util.__add_buf_highlight(item, state)
end

---@return boolean
function M.is_available()
  return (pcall(require, "telescope"))
end

-- Telescope function with preview and open functionality
---@param path string
---@param cb function
function M.files(path, cb)
  telescope.find_files {
    prompt_title = Util.format_title "pdf files",
    find_command = UtilPicker.find_command(path),
    previewer = pdf_previewer,
    attach_mappings = function(_, map)
      map("i", "<CR>", function(prompt_bufnr)
        ---@diagnostic disable-next-line: redundant-parameter
        local selected_file = action_state.get_selected_entry(prompt_bufnr)
        actions.close(prompt_bufnr)
        local pdf_path = selected_file.path
        cb(pdf_path)
      end)
      return true
    end,
  }
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

  pickers
    .new({}, {
      prompt_title = Util.format_title "bookmarks · [<C-x> delete]",
      finder = finders.new_table {
        results = contents,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry,
            ordinal = entry,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry then
            Mapping.default_bookmark(pdf_bookmark, cb, entry.value)
          end
        end)

        map({ "i", "n" }, "<C-x>", function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          Mapping.delete_bookmark_entry(pdf_bookmark, entry.value)

          -- Refresh list
          local current_picker = action_state.get_current_picker(prompt_bufnr)
          local new_contents = UtilPicker.bookmark_contents(pdf_bookmark.items)
          current_picker:refresh(
            finders.new_table {
              results = new_contents,
              entry_maker = function(e)
                return { value = e, display = e, ordinal = e }
              end,
            },
            { reset_prompt = false }
          )
        end)

        return true
      end,
    })
    :find()
end

function M.search()
  local renderer = require "pdfview.renderer"
  local state = renderer.get()

  local data = UtilPicker.search_cache(state)
  if not data then
    Util.warn("picker.telescope", "No active search")
    return
  end

  local contents = data.contents
  local seen = data.seen

  pickers
    .new({}, {
      prompt_title = Util.format_title "<query:" .. state.search.current_query .. ">",
      results_title = string.format("%d %s found", #contents, #contents == 1 and "result" or "results"),
      finder = finders.new_table {
        results = contents,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry,
            ordinal = entry,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry then
            Mapping.search(state, seen, entry.value)
          end
        end)

        return true
      end,
    })
    :find()
end

return M
