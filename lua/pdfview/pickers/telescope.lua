local telescope = require "telescope.builtin"
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
    local preview_text = M.preview_first_page(pdf_path)
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(preview_text, "\n"))
  end,
}

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
  Util.not_implemented_yet()
end

return M
