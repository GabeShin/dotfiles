return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		"nvim-tree/nvim-web-devicons",
		"folke/todo-comments.nvim",
	},
	keys = {
		{
			"<leader>ff",
			function()
				require("telescope.builtin").find_files()
			end,
			desc = "Find Files",
		},
		{
			"<leader>fg",
			function()
				require("telescope.builtin").live_grep()
			end,
			desc = "Live Grep",
		},
		{
			"<leader>fb",
			function()
				require("telescope.builtin").buffers()
			end,
			desc = "Find Buffers",
		},
		{
			"<leader>fo",
			function()
				require("telescope.builtin").man_pages()
			end,
			desc = "Map Pages",
		},
		{
			"<leader>fr",
			function()
				require("telescope.builtin").oldfiles()
			end,
			desc = "Recent Files",
		},
		{
			"<leaderf.fs",
			function()
				require("telescope.builtin").grep_string()
			end,
			desc = "Find String Under Cursor",
		},
		{
			"<leader>ft",
			function()
				require("telescope").extensions.todo_comments.todo()
			end,
			desc = "Find Todos",
		},
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		telescope.setup({
			defaults = {
				path_display = { "truncate" },
			},
		})

		telescope.load_extension("fzf")
	end,
}
