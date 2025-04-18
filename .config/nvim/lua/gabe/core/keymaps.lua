-- set leader key to space
vim.g.mapleader = " "

local keymap = vim.keymap -- for conciseness

---------------------
-- General Keymaps -------------------

-- Use <leader><leader> to save the file
keymap.set("n", "<leader><leader>", function()
	vim.cmd("w")
end)

-- use jk to exit insert mode
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

-- clear search highlights
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- delete without copying into register
keymap.set("n", "x", '"_x')
keymap.set("n", "d", '"_d')

-- increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management
keymap.set("n", "<C-w>/", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
keymap.set("n", "<C-w>-", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
keymap.set("n", "<C-w>e", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
keymap.set("n", "<C-w>x", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab

-- navigation helpers
keymap.set("n", "<leader>j", "<C-d>zz")
keymap.set("n", "<leader>k", "<C-u>zz")
keymap.set("n", "<leader>h", "<C-o>zz", { desc = "Go to previous jumplist" }) -- go to previous buffer
keymap.set("n", "<leader>l", "<C-i>zz", { desc = "Go to next jumplist" }) -- go to next buffer
keymap.set("n", "n", "nzzzv")
keymap.set("n", "N", "Nzzzv")

-- tmux navigation
keymap.set("n", "<C-h>", ":TmuxNavigateLeft<CR>")
keymap.set("n", "<C-j>", ":TmuxNavigateDown<CR>")
keymap.set("n", "<C-k>", ":TmuxNavigateUp<CR>")
keymap.set("n", "<C-l>", ":TmuxNavigateRight<CR>")

-- quickfix navigation
keymap.set("n", "[q", ":cnext<CR>")
keymap.set("n", "]q", ":cprev<CR>")
