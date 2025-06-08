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
			-- handlers now go inside `handlers = { … }`
			handlers = {
				-- default handler for all servers
				function(server_name)
					require("lspconfig")[server_name].setup({
						capabilities = require("cmp_nvim_lsp").default_capabilities(),
					})
				end,

				-- override for graphql
				["graphql"] = function()
					require("lspconfig").graphql.setup({
						capabilities = require("cmp_nvim_lsp").default_capabilities(),
						filetypes = { "graphql", "gql", "svelte", "typescriptreact", "javascriptreact" },
					})
				end,

				["emmet_ls"] = function()
					-- configure emmet language server
					require("lspconfig").emmet_ls.setup({
						capabilities = require("cmp_nvim_lsp").default_capabilities(),
						filetypes = {
							"html",
							"typescriptreact",
							"javascriptreact",
							"css",
							"sass",
							"scss",
							"less",
							"svelte",
						},
					})
				end,

				["lua_ls"] = function()
					-- configure lua server (with special settings)
					require("lspconfig").lua_ls.setup({
						capabilities = require("cmp_nvim_lsp").default_capabilities(),
						settings = {
							Lua = {
								-- make the language server recognize "vim" global
								diagnostics = {
									globals = { "vim" },
								},
								completion = {
									callSnippet = "Replace",
								},
							},
						},
					})
				end,
			},
		},
		config = function(_, opts)
			require("mason-lspconfig").setup(opts)
		end,
	},
}
