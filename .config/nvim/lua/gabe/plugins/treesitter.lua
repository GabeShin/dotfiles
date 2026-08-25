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

		-- nvim-ts-autotag is independent of the treesitter branch; it must be
		-- set up explicitly (the `main` rewrite no longer does it for you).
		require("nvim-ts-autotag").setup()

		local wanted = {
			"json",
			"javascript",
			"typescript",
			"tsx",
			"python",
			"rust",
			"toml",
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

		-- Ensure parsers are installed on startup (async)
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				local ts = require("nvim-treesitter")
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

		-- The `main` branch no longer auto-enables highlighting/indent.
		-- Start treesitter highlighting (and indent) per-buffer on FileType.
		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				local ok = pcall(vim.treesitter.start, args.buf)
				if ok then
					-- treesitter-based indentation (experimental upstream)
					vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end
			end,
		})
	end,
}
