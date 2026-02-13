local function shorter_name(filename)
	return filename:gsub(os.getenv("HOME"), "~"):gsub("/bin/python", "")
end

return {
	"linux-cultist/venv-selector.nvim",
	dependencies = {
		"neovim/nvim-lspconfig",
		"mfussenegger/nvim-dap",
		"mfussenegger/nvim-dap-python", --both are optionals for debugging
	},
	ft = "python", -- Load when opening Python files
	lazy = false,
	opts = {
		options = {},
	},
}
