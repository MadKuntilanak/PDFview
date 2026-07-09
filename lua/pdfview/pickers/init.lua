local M = {}

local Util = require "pdfview.utils"

-- NOTE: For maintainers: if you add a new picker interface, make sure to
-- register it here as well.
local AUTO_PICKER_PRIORITY = { "fzf-lua", "telescope" }

local silent_warn_notify = false

---@return string
local function default_picker()
  for _, name in ipairs(AUTO_PICKER_PRIORITY) do
    local ok, picker = pcall(require, string.format("pdfview.pickers.%s", name))
    if ok and picker.is_available and picker.is_available() then
      return name
    end
  end

  if not silent_warn_notify then
    Util.warn "The picker is falling back to the default `vim.ui.select`."
    silent_warn_notify = true
  end

  return "default"
end

---@param picker_name string?
local function get_picker(picker_name)
  picker_name = picker_name or ""

  if Util.is_blank(picker_name) then
    picker_name = default_picker()
  end

  local ok, picker = pcall(require, string.format("pdfview.pickers.%s", picker_name))

  if not ok then
    if not silent_warn_notify then
      Util.warn(
        string.format("The picker `%s` is not installed.\nFalling back to the default `vim.ui.select`.", picker_name)
      )
      silent_warn_notify = true
    end

    return get_picker "default"
  end

  if picker.is_available and not picker.is_available() then
    return get_picker()
  end

  return picker
end

---@param picker_name string
---@param path  string
---@param cb  function
function M.select(picker_name, method, path, cb)
  local p = get_picker(picker_name)

  if p and p[method] then
    p[method](path, cb)
  else
    Util.warn("The picker '" .. picker_name .. "' does not implement the '" .. method .. "' method.")
  end
end

return M
