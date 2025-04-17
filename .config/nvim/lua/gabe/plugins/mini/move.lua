return {
	"echasnovski/mini.move",
	branch = "stable",
	config = function()
		require("mini.move").setup({
			mappings = {
				-- Move visual selection in Visual mode.
				left = "<C-h>",
				right = "<C-l>",
				down = "<C-j>",
				up = "<C-k>",
			},
		})
	end,
}
