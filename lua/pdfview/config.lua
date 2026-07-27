local M = {}

---@type PDFviewCfg
M.defaults = {
  path = vim.fn.stdpath "config",
  save = vim.fn.stdpath "cache",
  picker = "default",
  open = {
    cb = nil,
  },
  window = {
    winhighlight = nil,
    text_search_indicator = {
      search = {
        fg = { hl = "Normal", attr = "bg" },
        bg = { hl = "Function", attr = "fg" },
        bold = true,
      },
      icon = {
        text = " ",
        fg = { hl = "Normal", attr = "bg" },
        bg = { hl = "WarningMsg", attr = "fg" },
      },

      sep = {
        back = "",
        front = "",
        fg = { hl = "Normal", attr = "bg" },
        bg = { hl = "WarningMsg", attr = "fg" },
      },

      text = {
        fg = { hl = "Normal", attr = "bg" },
        bg = { hl = "WarningMsg", attr = "fg" },
        bold = true,
      },
    },
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
    show_helps = "<Leader>?",
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
