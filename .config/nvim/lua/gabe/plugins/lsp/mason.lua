return {
	"mason-org/mason.nvim",
	dependencies = {
		"mason-org/mason-lspconfig.nvim",
		"neovim/nvim-lspconfig",
	},
	config = function()
		-- config mason
		require("mason").setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		-- config mason-lspconfig
		require("mason-lspconfig").setup({
			ensure_installed = {
				"ts_ls",
				"pyright",
				"html",
				"cssls",
				"tailwindcss",
				"lua_ls",
				"graphql",
				"emmet_ls",
				"prismals",
			},
		})
	end,
}
