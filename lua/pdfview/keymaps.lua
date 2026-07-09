local Config = require "pdfview.config"
local Util = require "pdfview.utils"
local renderer = require "pdfview.renderer"

local M = {}

---@param state PDFviewStateRender
local function save(state)
  local file_saved = Config.defaults.save
  if not Util.is_file(file_saved) then
    Util.create_file(file_saved)
  end

  local pdf_bookmarks = Util.get_pdf_bookmarks()
  if not pdf_bookmarks then
    return
  end

  local inserted_at = os.time()

  ---@type PDFviewBookmarkSaved
  local _data = {
    last_page = state.current_page,
    real_page = state.current_page + (state.page_offset or 0),
    total_pages = state.total_pages + (state.page_offset or 0),
    pdf_path = Config.defaults.pdf_path,
    created_at = inserted_at,
    text_page = "Page " .. state.current_page,
    text_path = vim.fn.fnamemodify(Config.defaults.pdf_path, ":~"),
  }

  pdf_bookmarks[#pdf_bookmarks + 1] = _data

  table.sort(pdf_bookmarks, function(a, b)
    return (a.created_at or 0) > (b.created_at or 0)
  end)

  Util.save_table_to_file(pdf_bookmarks, file_saved)
  Util.info("bookmark", string.format("Saved: %s · %s", _data.text_page, _data.text_path))
end

---@param state PDFviewStateRender
local function setup_pdfview_ft_mappings(ctx, state)
  local bufnr = ctx.buf

  vim.keymap.set("n", Config.defaults.keymaps.go_to_page, function()
    require("pdfview").go_to(nil, state)
  end, {
    buf = bufnr,
    desc = "go to page",
  })

  vim.keymap.set("n", Config.defaults.keymaps.show_page_in_zathura, function()
    require("pdfview").open_in_zathura(nil, state)
  end, {
    buf = bufnr,
    desc = "show page in zathura",
  })

  vim.keymap.set("n", Config.defaults.keymaps.next_page, renderer.next_page, {
    buf = bufnr,
    desc = "next page",
  })

  vim.keymap.set("n", Config.defaults.keymaps.prev_page, renderer.previous_page, {
    buf = bufnr,
    desc = "previous page",
  })

  vim.keymap.set("n", Config.defaults.keymaps.bookmark, function()
    require("pdfview").bookmark()
  end, {
    buf = bufnr,
    desc = "select bookmarks",
  })

  vim.keymap.set("n", Config.defaults.keymaps.save, function()
    save(state)
  end, {
    buf = bufnr,
    desc = "bookmark save",
  })

  vim.keymap.set("n", Config.defaults.keymaps.menu, function()
    require("pdfview").menu()
  end, {
    buf = bufnr,
    desc = "open menu",
  })
end

---@param group integer
---@param state PDFviewStateRender
local function augroup(group, state, cb)
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = state.filetype,
    desc = "PDFview filetype mappings",
    callback = function(ctx)
      cb(ctx)
    end,
  })
end

---@param tbl_keys {key: string|string[],fun: string|function, desc: string, buf?: integer }[]
function M.append_to(tbl_keys)
  for _, k in pairs(tbl_keys) do
    if type(k.key) == "table" then
      for _, __k in pairs(k.key) do
        if type(k.fun) == "function" then
          vim.keymap.set("n", __k, k.fun, { desc = k.desc, buf = k.buf })
        end
      end
    else
      if type(k.fun) == "function" then
        vim.keymap.set("n", k.key, k.fun, { desc = k.desc, buf = k.buf })
      end
    end
  end
end

---@param group integer
---@param state PDFviewStateRender
function M.setup_filetype_mappings(group, state)
  augroup(group, state, function(ctx)
    setup_pdfview_ft_mappings(ctx, state)
  end)
end

return M
