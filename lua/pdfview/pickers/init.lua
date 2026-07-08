local M = {}

local Util = require "pdfview.utils"

local function default_picker()
  return "default"
end

local silent_warn_notify = false

---@param picker_name string?
local function get_picker(picker_name)
  picker_name = picker_name or ""

  if Util.is_blank(picker_name) or silent_warn_notify then
    picker_name = default_picker()
  end

  local ok, picker = pcall(require, string.format("pdfview.pickers.%s", picker_name))

  if not ok then
    if not silent_warn_notify then
      Util.warn(
        string.format(
          "The picker `%s` has not been implemented yet.\nFalling back to the default `vim.ui.select`.",
          picker_name
        )
      )
    end

    silent_warn_notify = true

    return get_picker "default"
  end

  return picker
end

---@param picker_name string
---@param path  string
---@param cb  function
function M.select_file(picker_name, path, cb)
  local p = get_picker(picker_name)

  if p then
    p.select_file_pdf(path, cb)
  end
end

return M
