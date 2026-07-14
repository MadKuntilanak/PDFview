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

local idx = 1

---@param state PDFviewStateRender
---@param step integer
local function search(state, step)
  if not state.search or not state.search.cache or not state.search.current_query then
    return
  end

  local items = state.search.cache[state.search.current_query]

  local total_items = #items
  idx = ((idx - 1 + step) % total_items) + 1
  local item = items[idx]

  require("pdfview").go_to(item.page, state)
  Util.__add_buf_highlight(item, state)
end

---@param state PDFviewStateRender
local function next_search_text(state)
  search(state, 1)
end

---@param state PDFviewStateRender
local function prev_search_text(state)
  search(state, -1)
end

---@param ctx vim.api.keyset.create_autocmd.callback_args
---@param state PDFviewStateRender
local function setup_pdfview_ft_mappings(ctx, state)
  local pdfview = require "pdfview"
  local keymaps = Config.defaults.keymaps
  local bufnr = ctx.buf

  -- stylua: ignore
  ---@type PDFviewKeySpec[]
  local _keys = {
    { key = keymaps.go_to_page, fun = function() pdfview.go_to(nil, state, true) end, desc = "go to page", buf = bufnr },
    { key = keymaps.show_page_in_zathura, fun = function() pdfview.open_in_zathura(nil, state) end, desc = "show page in Zathura", buf = bufnr },
    { key = keymaps.next_page, fun = renderer.next_page, desc = "next page", buf = bufnr },
    { key = keymaps.prev_page, fun = renderer.previous_page, desc = "previous page", buf = bufnr },
    { key = keymaps.open_bookmark, fun = function() pdfview.select_bookmark() end, desc = "select bookmarks", buf = bufnr },
    { key = keymaps.save_bookmark, fun = function() save(state) end, desc = "save bookmark", buf = bufnr },
    { key = keymaps.menu, fun = function() pdfview.menu() end, desc = "open menu", buf = bufnr },

    { key = keymaps.search, fun = function() pdfview.search_text() end, desc = "search text", buf = bufnr },
    { key = keymaps.pick_search, fun = function() pdfview.select_search() end, desc = "select search result", buf = bufnr },
    { key = keymaps.next_search_text, fun = function() next_search_text(state) end, desc = "next search result", buf = bufnr },
    { key = keymaps.prev_search_text, fun = function() prev_search_text(state) end, desc = "previous search result", buf = bufnr },
  }

  M.append_to(_keys)

  local augroup = Util.create_augroup_name("SearchCleanup_" .. state.buf)
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    group = augroup,
    buffer = state.buf,
    once = true,
    callback = function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        -- pcall(vim.keymap.del, "n", "<F5>", { buffer = bufnr })
        if state.search then
          state.search = nil
        end
        if state.pages then
          state.pages = nil
        end
      end
    end,
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

---@param tbl_keys PDFviewKeySpec
function M.append_to(tbl_keys)
  for _, k in pairs(tbl_keys) do
    local keys = type(k.key) == "string" and { k.key } or k.key
    for _, key in ipairs(keys) do
      if type(k.fun) == "function" then
        vim.keymap.set("n", key, k.fun, {
          desc = k.desc,
          buffer = k.buf,
        })
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
