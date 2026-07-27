---@class PDFviewKeySpec
---@field key string|string[]
---@field fun string|function
---@field desc string
---@field buf? integer
---@field type? "menu"|"global"

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
---@field show_helps string

---@class PDFviewPopupTextSearchHl
---@field hl string,
---@field attr "fg"|"bg"

---@class PDFviewPopupTextSearchIndicator
---@field sep { back: string, front: string, fg: PDFviewPopupTextSearchHl, bg: PDFviewPopupTextSearchHl }
---@field icon { text: string, fg: PDFviewPopupTextSearchHl, bg: PDFviewPopupTextSearchHl }
---@field text { fg: PDFviewPopupTextSearchHl, bg: PDFviewPopupTextSearchHl, bold?: boolean }
---@field search { fg: PDFviewPopupTextSearchHl, bg: PDFviewPopupTextSearchHl, bold?: boolean }

---@class PDFviewWindow
---@field winhighlight string|nil
---@field text_search_indicator PDFviewPopupTextSearchIndicator

---@class PDFviewBookmarkSaved
---@field last_page integer
---@field real_page integer
---@field pdf_path string
---@field created_at number
---@field text_path string
---@field text_page string
---@field pages? table

---@class PDFviewCfg
---@field path string
---@field save string
---@field picker string
---@field window PDFviewWindow
---@field pdf_path string|nil
---@field keymaps PDFviewKeymaps
---@field open? {cb?:function}
---@field save_last_open? string
---@field ui? {cb?:function, menu?: table<integer, {idx: integer, item: string, shortcut: string, method: string}>}
---@field group? string
---@field show_helps? {key: string|table, desc: string, type?: "menu"|"global"}[]

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

---@class PDFviewStateO
---@field pages table
---@field page_offset integer
---@field total_pages integer
---@field current_page integer

---@class PDFviewStateRender
---@field current_page integer
---@field total_pages integer
---@field pdf_path string
---@field filetype string
---@field pages table
---@field o table<string, PDFviewStateO[]>
---@field buf integer|nil
---@field ns_id integer|nil
---@field ns_search_id integer|nil
---@field page_offset integer
---@field win_status_search_indicator? integer
---@field orginal_text? string
---@field win? integer
---@field search? PDFviewMatchQuery
