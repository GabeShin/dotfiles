return {
	{
		-- williamboman/mason.nvim was transferred to the mason-org org; the
		-- old path only still works because GitHub redirects it.
		"mason-org/mason.nvim",
		config = function()
			require("mason").setup({
				ui = {
					icons = {
						package_installed = "✓",
						package_pending = "➜",
						package_uninstalled = "✗",
					},
				},
			})
		end,
	},
	{
		"mason-org/mason-lspconfig.nvim",
		dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
		opts = {
			ensure_installed = {
				"ts_ls",
				"tailwindcss",
				"pyright",
				"ruff",
				"lua_ls",
				"html",
				"cssls",
				"graphql",
				"emmet_ls",
				"prismals",
				"rust_analyzer",
				-- conform formats toml with taplo, which was configured but
				-- never installed, so every .toml write warned "Formatters
				-- unavailable for toml file". Installing it here puts the
				-- binary on mason's PATH for conform and gives toml an LSP.
				"taplo",
			},
			-- automatically call vim.lsp.enable() on installed servers
			automatic_enable = true,
		},
		config = function(_, opts)
			require("mason-lspconfig").setup(opts)
		end,
	},
}
