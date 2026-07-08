local Config = require "pdfview.config"
local Util = require "pdfview.utils"

local parser = require "pdfview.parser"
local renderer = require "pdfview.renderer"

local M = {}

---@param opts PDFviewCfg
function M.setup(opts)
  Config.update_settings(opts)

  local pdf_render = require "pdfview.renderer"
  local group = vim.api.nvim_create_augroup("PDFview", { clear = true })
  pdf_render.setup_filetype_mappings(group)
end

function M.select_file_pdf()
  local p = require "pdfview.pickers"
  local path = Config.defaults.path
  if not Util.is_dir(path) then
    return
  end

  p.select_file(Config.defaults.picker or "default", path, function(pdf_path)
    if not Util.is_file(pdf_path) then
      Util.warn("PDF path doesn't exist: `" .. pdf_path .. "`")
      return
    end

    Config.defaults.pdf_path = pdf_path
    M.open(pdf_path)

    if Config.defaults.open and Config.defaults.open.cb then
      if type(Config.defaults.open.cb) ~= "function" then
        return
      end
      Config.defaults.open.cb(pdf_path)
    end
  end)
end

-- Function to open the full PDF text (runs when PDF is selected)
---@param pdf_path string
function M.open(pdf_path)
  local text = parser.extract_text(pdf_path)
  if text then
    renderer.display_text(text)
  end
end

-- Function to extract and display the first page (used for preview)
---@param pdf_path string
---@return string
function M.preview_first_page(pdf_path)
  local first_page_text = parser.extract_text(pdf_path, 1, 1)
  if first_page_text then
    return first_page_text
  else
    return "Could not extract text from the first page of the PDF."
  end
end

return M
