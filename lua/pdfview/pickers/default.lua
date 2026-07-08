local UtilPicker = require "pdfview.pickers.utils"

local M = {}

local function get_files(path)
  local cmd = UtilPicker.find_command(path)
  local files = vim.fn.systemlist(cmd)
  return files
end

---@param path string
---@param cb function
function M.select_file_pdf(path, cb)
  local files = get_files(path)
  vim.ui.select(files, { prompt = "PDFview" }, function(file)
    if not file then
      return
    end

    local pdf_path = vim.fs.normalize(file)
    cb(pdf_path)
  end)
end

return M
