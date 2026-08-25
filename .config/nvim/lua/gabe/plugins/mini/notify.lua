return {
	"echasnovski/mini.notify",
	branch = "stable",
	config = function()
		require("mini.notify").setup({
			lsp_progress = {
				enable = false,
			},
		})
	end,
}
