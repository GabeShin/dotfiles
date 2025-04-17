return {
	"kevinhwang91/nvim-ufo",
	dependencies = "kevinhwang91/promise-async",
	opts = {
		open_fold_hl_timeout = 150,
		close_fold_kinds_for_ft = {
			default = { "imports", "comment" },
			json = { "array" },
			c = { "comment", "region" },
		},
		provider_selector = function(bufnr, filetype, buftype)
			return { "treesitter", "indent" }
		end,
	},
	config = function(_, opts)
		require("ufo").setup(opts)

		vim.o.foldcolumn = "1" -- '0' is not bad
		vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
		vim.o.foldlevelstart = 99
		vim.o.foldenable = true

		local keymap = vim.keymap
		local ufo = require("ufo")

		keymap.set("n", "zR", ufo.openAllFolds)
		keymap.set("n", "zM", ufo.closeAllFolds)
		keymap.set("n", "zr", ufo.openFoldsExceptKinds)
		keymap.set("n", "zm", ufo.closeFoldsWith) -- closeAllFolds == closeFoldsWith(0)
	end,
}
