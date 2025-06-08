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
	lazy = false,
	branch = "regexp", -- This is the regexp branch, use this for the new version
	opts = {
		options = {
			-- If you put the callback here as a global option, its used for all searches (including the default ones by the plugin)
			on_telescope_result_callback = shorter_name,
		},
	},
}
