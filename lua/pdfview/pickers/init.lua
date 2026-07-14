local M = {}

local Util = require "pdfview.utils"

-- NOTE: For maintainers: if you add a new picker interface, make sure to
-- register it here as well.
local AUTO_PICKER_PRIORITY = { "fzf-lua", "snacks", "telescope", "default" }

local silent_warn_notify = false
local warn_msg_picker_not_installed
local set_picker

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
local function resolve_picker(picker_name)
  picker_name = picker_name or ""

  if Util.is_blank(picker_name) then
    picker_name = default_picker()
  end

  local ok, picker = pcall(require, string.format("pdfview.pickers.%s", picker_name))

  if not ok then
    if not silent_warn_notify then
      warn_msg_picker_not_installed = string.format("The picker `%s` is not installed", picker_name)
    end

    set_picker = default_picker()
    return resolve_picker(set_picker)
  end

  if picker.is_available and not picker.is_available() then
    return resolve_picker()
  end

  if ok and not silent_warn_notify and warn_msg_picker_not_installed then
    Util.warn(string.format("%s.\nFalling back to the picker `%s`.", warn_msg_picker_not_installed, picker_name))
    silent_warn_notify = true
  end

  set_picker = picker_name
  return picker
end

local p

local function setup_picker(picker_name)
  if p then
    return p
  end
  p = resolve_picker(picker_name)
  return p
end

---@param picker_name string
---@param path  string
---@param cb  function|nil
function M.select(picker_name, method, path, cb)
  p = setup_picker(picker_name)
  if not p or not p[method] then
    Util.warn("picker", "The picker '" .. set_picker .. "' does not implement the '" .. method .. "' method.")
    return
  end

  p[method](path, cb)
end

return M
