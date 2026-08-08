local Config = require "pdfview.config"
local Util = require "pdfview.utils"
local renderer = require "pdfview.renderer"

local M = {}

---@param state PDFviewStateRender
---@param is_last_open? boolean
local function save(state, is_last_open)
  is_last_open = is_last_open or false
  local file_saved = is_last_open and Config.defaults.save_last_open or Config.defaults.save

  if not Util.is_file(file_saved) then
    Util.create_file(file_saved)
  end

  local pdf_bookmark = Util.get_pdf_bookmarks()
  if not pdf_bookmark then
    return
  end

  local inserted_at = os.time()

  ---@type PDFviewBookmarkSavedData
  local _data = {
    last_page = state.current_page,
    real_page = state.current_page + (state.page_offset or 0),
    total_pages = state.total_pages + (state.page_offset or 0),
    pdf_path = Config.defaults.pdf_path,
    created_at = inserted_at,
    text_page = "Page " .. state.current_page,
    text_path = vim.fn.fnamemodify(Config.defaults.pdf_path, ":~"),
  }

  if is_last_open then
    -- local pages = state.pages
    -- if Util.is_blank(pages) then
    --   local full_text = require("pdfview.parser").extract_text(Config.defaults.pdf_path)
    --   pages = full_text and renderer.paginate_text(full_text) or {}
    -- end

    _data.pages = state.pages or {}
    Util.save_table_to_file(_data, file_saved)
    return
  end

  if not pdf_bookmark.__o then
    pdf_bookmark.__o = {}
  end

  local tbl_o = renderer.get().o[Config.defaults.pdf_path]
  if tbl_o and not pdf_bookmark.__o[Config.defaults.pdf_path] then
    pdf_bookmark.__o[Config.defaults.pdf_path] = tbl_o
  end

  if not pdf_bookmark.items then
    pdf_bookmark.items = {}
  end
  table.insert(pdf_bookmark.items, _data)
  -- pdf_bookmark.items[#pdf_bookmark.items + 1] = _data

  table.sort(pdf_bookmark, function(a, b)
    return (a.created_at or 0) > (b.created_at or 0)
  end)

  Util.save_table_to_file(pdf_bookmark, file_saved)
  Util.info("bookmark", string.format("Saved: %s · %s", _data.text_page, _data.text_path))
end

---@param state PDFviewStateRender
---@param step integer
---@param bufnr integer
local function search(state, step, bufnr)
  if not state.search or not state.search.cache or not state.search.current_query then
    return
  end

  local items = state.search.cache[state.search.current_query]
  local idx = state.search.current_idx or 0

  local total_items = #items
  idx = ((idx - 1 + step) % total_items) + 1
  local item = items[idx]

  state.search.current_idx = idx

  require("pdfview").go_to(item.page, state)
  Util.__add_buf_highlight(item, state, idx, total_items)

  --- Attach a keybinding to delete search indicators.
  if state.win_status_search_indicator and vim.api.nvim_win_is_valid(state.win_status_search_indicator) then
    vim.keymap.set("n", "<Esc>", function()
      if state.win_status_search_indicator and vim.api.nvim_win_is_valid(state.win_status_search_indicator) then
        vim.api.nvim_win_close(state.win_status_search_indicator, true)
        pcall(vim.keymap.del, "n", "<Esc>", { buffer = bufnr })
      end
    end)
    vim.keymap.set("n", "q", function()
      if state.win_status_search_indicator and vim.api.nvim_win_is_valid(state.win_status_search_indicator) then
        vim.api.nvim_win_close(state.win_status_search_indicator, true)
        pcall(vim.keymap.del, "n", "q", { buffer = bufnr })
      end
    end)
  end
end

---@param state PDFviewStateRender
---@param bufnr integer
local function next_search_text(state, bufnr)
  search(state, 1, bufnr)
end

---@param state PDFviewStateRender
---@param bufnr integer
local function prev_search_text(state, bufnr)
  search(state, -1, bufnr)
end

local _h_keys = {}

---@param ctx vim.api.keyset.create_autocmd.callback_args
---@param state PDFviewStateRender
local function setup_pdfview_ft_mappings(ctx, state)
  local pdfview = require "pdfview"
  local keymaps = Config.defaults.keymaps
  local bufnr = ctx.buf

  -- stylua: ignore
  ---@type PDFviewKeySpec[]
  local _keys = {
    { key = keymaps.go_to_page, fun = function() pdfview.go_to(nil, state, false) end, desc = "go to page", buf = bufnr },
    { key = keymaps.show_page_in_zathura, fun = function() pdfview.open_in_zathura(nil, state) end, desc = "show page in Zathura", buf = bufnr },
    { key = keymaps.next_page, fun = renderer.next_page, desc = "next page", buf = bufnr },
    { key = keymaps.prev_page, fun = renderer.previous_page, desc = "previous page", buf = bufnr },
    { key = keymaps.open_bookmark, fun = function() pdfview.select_bookmark() end, desc = "select bookmarks", buf = bufnr },
    { key = keymaps.save_bookmark, fun = function() save(state) end, desc = "save bookmark", buf = bufnr },
    { key = keymaps.menu, fun = function() pdfview.menu() end, desc = "open menu", buf = bufnr },

    { key = keymaps.search, fun = function() pdfview.text_search() end, desc = "search text", buf = bufnr },
    { key = keymaps.pick_search, fun = function() pdfview.select_text_search() end, desc = "select search result", buf = bufnr },
    { key = keymaps.next_search_text, fun = function() next_search_text(state, bufnr) end, desc = "next search result", buf = bufnr },
    { key = keymaps.prev_search_text, fun = function() prev_search_text(state, bufnr) end, desc = "previous search result", buf = bufnr },

    { key = keymaps.next_jumplist, fun = function() pdfview.jumplist(1) end, desc = "forward history page", buf = bufnr },
    { key = keymaps.prev_jumplist, fun = function() pdfview.jumplist(-1) end, desc = "backward history page", buf = bufnr },

    { key = keymaps.show_helps, fun = function() require("pdfview.ui").call("show_keymap_helps", Config.defaults) end, desc = "show helps", buf = bufnr },
  }

  M.append_to(_keys)

  if not Config.defaults.show_helps then
    Config.defaults.show_helps = {}
  end

  Config.defaults.show_helps = _h_keys

  local augroup = Util.create_augroup_name("SearchCleanup_" .. state.buf)
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    group = augroup,
    buffer = state.buf,
    once = true,
    callback = function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        if state.win_status_search_indicator and vim.api.nvim_win_is_valid(state.win_status_search_indicator) then
          vim.api.nvim_win_close(state.win_status_search_indicator, true)
          pcall(vim.keymap.del, "n", "<Esc>", { buffer = bufnr })
          pcall(vim.keymap.del, "n", "q", { buffer = bufnr })
        end

        save(state, true)

        -- FIX: temporarily commented out. If triggered between the two events above,
        -- `pages` can become `nil`, causing `save()` to run twice and overwrite the
        -- existing data with `nil`.
        -- if state.search then
        --   state.search = nil
        -- end
        -- if state.pages then
        --   state.pages = nil
        -- end
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
    table.insert(_h_keys, { key = k.key, desc = k.desc, type = k.type and k.type or "global" })
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
