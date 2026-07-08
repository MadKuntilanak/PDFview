local Plenary_path = require "plenary.path"

local M = {}

function M.is_iterm2()
  return vim.env.TERM_PROGRAM == "iTerm.app"
end

function M.is_kitty()
  return vim.env.TERM == "xterm-kitty"
end

---@param module_or_message string
---@param message? string
local function notify(hl, module_or_message, message)
  local module

  if message == nil then
    message = module_or_message
  else
    module = module_or_message
  end

  local prefix = module and ("PDFview." .. module) or "PDFview"

  vim.api.nvim_echo({
    { ("(%s) "):format(prefix), hl },
    { message },
  }, true, {})
end

---@param module_or_message string
---@param message? string
function M.info(module_or_message, message)
  notify("Directory", module_or_message, message)
end

---@param module_or_message string
---@param message? string
function M.warn(module_or_message, message)
  notify("WarningMsg", module_or_message, message)
end

---@param module_or_message string
---@param message? string
function M.error(module_or_message, message)
  notify("ErrorMsg", module_or_message, message)
end

---@param msg? string
function M.not_implemented_yet(msg)
  if msg == nil then
    msg = ""
  end
  if #msg > 0 then
    msg = "Not impelemented, -> " .. msg
  else
    msg = "Not impelemented yet"
  end
  M.warn(msg)
end

---@return boolean
function M.is_blank(s)
  return (
    s == nil
    or s == vim.NIL
    or (type(s) == "string" and string.match(s, "%S") == nil)
    or (type(s) == "table" and next(s) == nil)
  )
end

---@param filename string
---@return boolean | string
function M.exists(filename)
  local stat
  if filename then
    stat = vim.loop.fs_stat(filename)
  end

  return stat and stat.type or false
end

---@param filename string
---@return boolean
function M.is_dir(filename)
  return M.exists(filename) == "directory"
end

---@return boolean
function M.is_file(filename)
  return M.exists(filename) == "file"
end

function M.create_file(path)
  local p = Plenary_path.new(path)
  if not p:exists() then
    p:touch()
  end
end

function M.create_dir(path)
  local p = Plenary_path.new(path)
  if not p:exists() then
    p:mkdir()
  end
end

function M.system_cmd(cmds)
  vim.system(cmds, { detach = true }, function(res)
    if res.code ~= 0 then
      vim.schedule(function()
        ---@diagnostic disable-next-line: undefined-field
        M.error("failed to open Zathura:" .. (res.stderr or ""))
      end)
    end
  end)
end

---@param name string
---@param opts? {group: string}
function M.create_augroup_name(name, opts)
  opts = opts or { group = "PDFview" }
  return vim.api.nvim_create_augroup(opts.group .. name, { clear = true })
end

---@param augroup_name string
function M.clear_autocmd_group(augroup_name)
  pcall(vim.api.nvim_clear_autocmds, { group = augroup_name })
  pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
end

return M
