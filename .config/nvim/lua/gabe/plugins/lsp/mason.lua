return {
	{
		"williamboman/mason.nvim",
		-- your file no longer shadows because it's named `mason-config.lua`
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
		"williamboman/mason-lspconfig.nvim",
		after = "mason.nvim",
		dependencies = { "neovim/nvim-lspconfig" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					-- javascript
					"ts_ls",
					"tailwindcss",
					-- python
					"pyright",
					"black",
					"ruff",
					"mypy",
					-- lua
					"lua_ls",
					-- web
					"html",
					"cssls",
					-- others
					"graphql",
					"emmet_ls",
					"prismals",
				},
			})
		end,
	},
}
