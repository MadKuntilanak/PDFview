local M = {}

---@type PDFviewCfg
M.defaults = {
  path = vim.fn.stdpath "config",
  save = vim.fn.stdpath "state",
  picker = "default",
  open = {
    cb = nil,
  },
  window = {
    winhighlight = nil,
  },
  keymaps = {
    menu = "<CR>",
    go_to_page = "gf",
    show_page_in_zathura = "<Leader>x",
    next_page = "<a-n>",
    prev_page = "<a-p>",
    open_bookmark = "b",
    save_bookmark = "s",
    search = "<C-s>",
    pick_search = "<Leader>s",
    next_search_text = "<C-n>",
    prev_search_text = "<C-p>",
  },
}

---@param cfg_tbl PDFviewCfg
---@param opts PDFviewCfg
local function merge_settings(cfg_tbl, opts)
  opts = opts or {}
  local def = vim.tbl_deep_extend("force", cfg_tbl, opts)
  return def
end

---@param opts PDFviewCfg
function M.update_settings(opts)
  opts = opts or {}

  M.defaults = merge_settings(M.defaults, opts)
end

return M
