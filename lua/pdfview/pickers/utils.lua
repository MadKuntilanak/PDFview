local M = {}

---@param path string
---@return string[]
function M.find_command(path)
  return { "find", path or ".", "-type", "f", "-name", "*.pdf" }
end

return M
