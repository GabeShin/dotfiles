return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		on_attach = function(bufnr)
			local gs = package.loaded.gitsigns

			local function map(mode, l, r, desc)
				vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
			end

			-- Navigation
			-- gs.next_hunk / gs.prev_hunk are deprecated in favour of the single
			-- gs.nav_hunk(direction).
			map("n", "]h", function()
				gs.nav_hunk("next")
			end, "Next Hunk")
			map("n", "[h", function()
				gs.nav_hunk("prev")
			end, "Prev Hunk")

			-- Actions
			map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
			map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
			-- gitsigns wants an ascending range, and line(".") is only above
			-- line("v") when the selection was dragged downwards.
			local function visual_range()
				local a, b = vim.fn.line("."), vim.fn.line("v")
				return { math.min(a, b), math.max(a, b) }
			end

			map("v", "<leader>hs", function()
				gs.stage_hunk(visual_range())
			end, "Stage hunk")
			map("v", "<leader>hr", function()
				gs.reset_hunk(visual_range())
			end, "Reset hunk")

			map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
			map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")

			-- gs.undo_stage_hunk is deprecated: gs.stage_hunk now unstages when
			-- it is called on an already-staged hunk. Keeping the key so the
			-- habit still works.
			map("n", "<leader>hu", gs.stage_hunk, "Unstage hunk (toggle)")

			map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")

			map("n", "<leader>hb", function()
				gs.blame_line({ full = true })
			end, "Blame line")
			map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle line blame")

			map("n", "<leader>hd", gs.diffthis, "Diff this")
			map("n", "<leader>hD", function()
				gs.diffthis("~")
			end, "Diff this ~")

			-- Text object
			map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Gitsigns select hunk")
		end,
	},
}
