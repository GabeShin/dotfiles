return {
	{
		"mfussenegger/nvim-dap-python",
		config = function()
			local path = "~/.local/share/nvim/mason/packages/debugpy/venv/bin/python"
			local dap_python = require("dap-python")
			dap_python.setup(path)

			-- test function
			local opts = { noremap = true, silent = true }
			vim.keymap.set("n", "<leader>dpr", function()
				dap_python.test_method()
			end, opts)
		end,
	},
}
