return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local conform = require("conform")

		conform.setup({
			formatters_by_ft = {
				javascript = { "prettier" },
				typescript = { "prettier" },
				javascriptreact = { "prettier" },
				typescriptreact = { "prettier" },
				svelte = { "prettier" },
				css = { "prettier" },
				html = { "prettier" },
				json = { "prettier" },
				yaml = { "prettier" },
				markdown = { "prettier" },
				graphql = { "prettier" },
				liquid = { "prettier" },
				lua = { "stylua" },
				python = { "black" },
				rust = { "rustfmt" },
				toml = { "taplo" },
			},
			format_on_save = {
				-- `lsp_fallback` is deprecated in conform; `lsp_format` took
				-- over and takes a string rather than a boolean.
				lsp_format = "fallback",
				async = false,
				timeout_ms = 5000,
			},
		})
	end,
}
