local M = {}

local Util = require "pdfview.utils"

-- NOTE: For maintainers: if you add a new picker interface, make sure to register it here as well.
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
    Util.warn(
      "picker",
      string.format("%s.\nFalling back to the picker `%s`.", warn_msg_picker_not_installed, picker_name)
    )
    silent_warn_notify = true
  end

  set_picker = picker_name
  return picker
end

local resolved_pickers = {}

local function setup_picker(picker_name)
  local cache_key = picker_name or "__auto__"
  if resolved_pickers[cache_key] then
    return resolved_pickers[cache_key]
  end
  local picker = resolve_picker(picker_name)
  resolved_pickers[cache_key] = picker
  return picker
end

---@param picker_name string
---@param method string
---@param path  string
---@param cb  function|nil
function M.select(picker_name, method, path, cb)
  local picker = setup_picker(picker_name)
  if not picker or not picker[method] then
    Util.warn(
      "picker",
      string.format("The picker '%s' does not implement the '%s' method.", picker_name or "auto", method)
    )
    return
  end

  picker[method](path, cb)
end

return M
