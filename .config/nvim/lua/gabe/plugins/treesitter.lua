return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	event = { "BufReadPre", "BufNewFile" },
	build = ":TSUpdate",
	dependencies = {
		"windwp/nvim-ts-autotag",
	},
	config = function()
		require("nvim-treesitter").setup()

		-- Ensure parsers are installed on startup
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				local ts = require("nvim-treesitter")
				local wanted = {
					"json",
					"javascript",
					"typescript",
					"tsx",
					"python",
					"yaml",
					"html",
					"css",
					"prisma",
					"markdown",
					"markdown_inline",
					"graphql",
					"bash",
					"lua",
					"vim",
					"dockerfile",
					"gitignore",
					"query",
					"vimdoc",
					"c",
				}
				local installed = {}
				for _, p in ipairs(ts.get_installed()) do
					installed[p] = true
				end
				local missing = vim.tbl_filter(function(p)
					return not installed[p]
				end, wanted)
				if #missing > 0 then
					ts.install(missing)
				end
			end,
			once = true,
		})
	end,
}
