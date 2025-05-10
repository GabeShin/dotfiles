return {
	{
		"nvim-neotest/nvim-nio",
		dependencies = {
			"mfussenegger/nvim-dap-python",
		},
		config = function()
			local dap_python = require("dap-python")
			dap_python.setup("python3")
		end,
	},
}
