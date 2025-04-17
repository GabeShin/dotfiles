return {
	{
		"CopilotC-Nvim/CopilotChat.nvim",
		dependencies = {
			{ "github/copilot.vim" }, -- or zbirenbaum/copilot.lua
			{ "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
		},
		build = "make tiktoken", -- Only on MacOS or Linux
		opts = {
			-- See Configuration section for options
		},
		-- See Commands section for default commands if you want to lazy load on them
		keys = {
			{ "<leader>cc", "<cmd>CopilotChatToggle<CR>", desc = "Chat with Copilot" },
			{ "<leader>ce", "<cmd>CopilotChatExplain<CR>", desc = "Explain code with Copilot" },
			{ "<leader>cf", "<cmd>CopilotChatFix<CR>", desc = "Fix code with Copilot" },
			{ "<leader>cr", "<cmd>CopilotChatReview<CR>", desc = "Review code with Copilot" },
			{ "<leader>co", "<cmd>CopilotChatOptimize<CR>", desc = "Optimize code with Copilot" },
			{ "<leader>ct", "<cmd>CopilotChatTests<CR>", desc = "Generate tests for code with Copilot" },
		},
	},
}
