---@class PDFviewKeySpec
---@field key string|string[]
---@field fun string|function
---@field desc string
---@field buf? integer

---@class PDFviewKeymaps
---@field go_to_page string
---@field show_page_in_zathura string
---@field next_page string
---@field prev_page string
---@field open_bookmark string
---@field menu string
---@field save_bookmark string
---@field search string
---@field pick_search string
---@field next_search_text string
---@field prev_search_text string

---@class PDFviewPopup
---@field winhighlight string|nil

---@class PDFviewBookmarkSaved
---@field last_page integer
---@field real_page integer
---@field pdf_path string
---@field created_at number
---@field text_path string
---@field text_page string

---@class PDFviewCfg
---@field path string
---@field save string
---@field picker string
---@field window PDFviewPopup
---@field pdf_path string|nil
---@field keymaps PDFviewKeymaps
---@field open? {cb?:function}
---@field ui? {cb?:function, menu?: table<integer, {idx: integer, item: string, shortcut: string, method: string}>}
---@field group? string

---@class PDFviewMatch
---@field page integer
---@field line integer
---@field col integer
---@field text string
---@field text_line string
---@field filename string

---@class PDFviewMatchQuery
---@field current_query string
---@field cache table<string, PDFviewMatch[]>

---@class PDFviewStateRender
---@field current_page integer
---@field total_pages integer
---@field pdf_path string
---@field filetype string
---@field pages table
---@field buf integer|nil
---@field ns_id integer|nil
---@field ns_search_id integer|nil
---@field page_offset integer
---@field win? integer
---@field search? PDFviewMatchQuery
