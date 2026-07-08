local Util = require "pdfview.utils"

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

---@param title string
local function format_title(title)
  return " " .. title .. " "
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

---@param path string
---@param cb function
function M.select_file_pdf(path, cb)
  setup_fzflua()

  if not loaded then
    return
  end

  FzfLua.files {
    cwd = path,
    no_header = true,
    no_header_i = true, -- hide interactive header?
    fzf_opts = { ["--header"] = [[^x:delete  ^r:rename]] },
    winopts = { title = format_title "PDFview", preview = { hidden = true } },
    actions = {
      ["default"] = Mapping.default(path, cb),
    },
  }
end

return M
