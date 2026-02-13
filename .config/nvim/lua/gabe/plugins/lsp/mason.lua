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
			},
			-- automatically call vim.lsp.enable() on installed servers
			automatic_enable = true,
		},
		config = function(_, opts)
			require("mason-lspconfig").setup(opts)
		end,
	},
}
