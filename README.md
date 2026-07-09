
# PDFview.nvim - A Neovim Plugin for Viewing PDFs

**PDFview.nvim** is a Neovim plugin designed for users who want to open, view, and navigate PDF documents directly within Neovim. It is particularly useful for those who want to integrate their workflow with Obsidian or other note-taking systems, allowing you to quickly open PDFs, extract text, and navigate through pages, all from within Neovim.

---

## Features

- **Open PDF Files**: Quickly search and open PDF files using the currently supported pickers: `telescope.nvim`, `fzf-lua`, or the built-in `vim.ui.select`.
- **Extract Text**: Extract the text from a PDF using `pdftotext` for easy reading or note-taking.
- **Pagination**: Navigate through the document using next/previous page commands.
- **Customizable Pagination**: Set how many lines per page should be displayed.
- **Virtual Text Display**: See page numbers displayed in the buffer.
- **Bookmarks**: Save your reading position with a bookmark and jump back to it anytime.


<img width="800" height="495" alt="260709-14-22-34" src="https://github.com/user-attachments/assets/20ce5aa0-ffca-4972-9ca4-501736de00ac" />



---

## Installation

### Prerequisites

- **Neovim** version 0.5 or higher
- **Picker**: **Telescope.nvim** (optional), **Fzf-lua** (optional), or the **default** picker (`vim.ui.select`)
- **[Zathura](https://github.com/pwmt/zathura)**: document viewer
  ```bash
  sudo apt install zathura
  ```
- **pdftotext**: this plugin relies on the `pdftotext` command-line tool to extract text from PDFs. Install it using the following command:
  ```bash
  sudo apt install poppler-utils
  ```

### Installation with LazyVim

To install `PDFview.nvim` using **LazyVim**, add the following configuration to your Neovim setup:

```lua
{
  "basola21/PDFview",
  event = "VeryLazy",
  dependencies = { 
    "nvim-telescope/telescope.nvim" 
  },
  opts = {
    path = "/path/to/pdf_folder", -- path pdf folder
    save = "/path/to/save_folder", -- bookmark save folder
    picker = "default", -- fzf-lua, telescope, default (using vim.ui.select)
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
      bookmark = "b",
      save = "s",
    },
    keys = {
      {
        "<Leader>fp",
        function()
          require("pdfview").select_file_pdf()
        end,
        desc = "Select pdf file",
      },
      {
        "<Leader>fP",
        function()
          require("pdfview").menu()
        end,
        desc = "Open menu",
      },
  },
},
```

### Mappings

The `next_page` and `prev_page` keymaps are already set up for you in the `opts.keymaps` table above.
However, if you'd rather define your own custom keys instead of using the built-in ones, you can call the underlying functions directly:

```lua
-- Open menu pdfview
map("n", "<leader>ff", "<cmd>:lua require('pdfview').menu()<CR>", { desc = "PDFview: Menu" })

-- Navigate to the next page in the PDF
map("n", "<leader>jj", "<cmd>:lua require('pdfview.renderer').next_page()<CR>", { desc = "PDFview: Next page" })

-- Navigate to the previous page in the PDF
map("n", "<leader>kk", "<cmd>:lua require('pdfview.renderer').previous_page()<CR>", { desc = "PDFview: Previous page" })
```

---

## Usage

1. **Opening a PDF File**  
   Use the following command to open a PDF:
   ```lua
   require("pdfview").select_file_pdf()
   -- or
   require("pdfview").menu()
   ```
   This will open Telescope's file finder, allowing you to search for PDF files in your project or system.

2. **Navigating Pages**  
   Use the defined key mappings to navigate between pages:
   - `<a-n>` or `<leader>jj` for the next page.
   - `<a-p>` or `<leader>kk` for the previous page.

3. **Extracting Text from a PDF**  
   When you select a PDF using Telescope, the plugin extracts the text using `pdftotext` and displays it in a buffer, allowing for easy reading or note-taking.

4. **Adding Autocmd**  
   Add these lines in your nvim config to open pdf's with PDFview:
   ```lua
    vim.api.nvim_create_autocmd("BufReadPost", {
      pattern = "*.pdf",
      callback = function()
        local file_path = vim.api.nvim_buf_get_name(0)
        require("pdfview").open(file_path)
      end,
    })
   ```
---

## Configuration

### Support callback

You can define a custom callback function (`open.cb`) that gets triggered whenever a PDF is opened, receiving the PDF's file path as an argument. This is useful for integrating with other plugins, for example, automatically sending the opened PDF to codecompanion.nvim for translation or summarization.

Example using `codecompanion.nvim`:

```lua
  
  ... -- default config
  open = {
     cb = function(pdf_path)
       vim.api.nvim_input ":CodeCompanion /translator_role <CR>"
     end,
  },
```

### Support Statusline

Example using `heirline.nvim`:

```lua
local get_pdfview = function()
  if not pdfview then
    local ok, session = pcall(require, "pdfview.renderer")
    if ok then
      pdfview = session
    end
  end
  return pdfview
end


...

{
  ...
	provider = function()
		if vim.bo.filetype == "pdfview" then
			if not pdfview then
				pdfview = get_pdfview()
			end

			local pdf_render = pdfview.get()
			if pdf_render and pdf_render.pdf_path then
				return vim.fn.fnamemodify(pdf_render.pdf_path, ":~") .. " (Page " .. pdf_render.current_page .. ")"
			end
		end
	end,
}

```

---

## Planned Features

- **Improved Navigation**: Refine the pagination and scrolling behavior for a smoother reading experience.
- **Document Search**: Implement a search feature to find specific text within the PDF.
- **Improved Structure**: Enhance the project structure for better maintainability and scalability.

---

## Contribution

Contributions are welcome! Feel free to open issues or submit pull requests to help improve the plugin.

1. Fork the repository.
2. Create a new branch (`git checkout -b feature/my-feature`).
3. Commit your changes (`git commit -m 'Add some feature'`).
4. Push to the branch (`git push origin feature/my-feature`).
5. Open a pull request.

---

## License

This project is licensed under the MIT License.

---

## Support

If you encounter any issues or have feature requests, please open an issue in the [GitHub repository](https://github.com/basola21/PDFview).

---

Enjoy using **PDFview.nvim** for your Neovim-based PDF viewing and note-taking workflow!
