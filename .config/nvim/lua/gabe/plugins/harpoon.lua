return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	requires = { { "nvim-lua/plenary.nvim" } },
	config = function()
		local harpoon = require("harpoon")
		local keymap = vim.keymap

		keymap.set("n", "<leader>a", function()
			harpoon.mark.add_file()
		end, { desc = "Add file to harpoon" })

		keymap.set("n", "<leader>1", function()
			harpoon.ui.nav_file(1)
		end, { desc = "Navigate to file 1" })
		keymap.set("n", "<leader>2", function()
			harpoon.ui.nav_file(2)
		end, { desc = "Navigate to file 2" })
		keymap.set("n", "<leader>3", function()
			harpoon.ui.nav_file(3)
		end, { desc = "Navigate to file 3" })
		keymap.set("n", "<leader>4", function()
			harpoon.ui.nav_file(4)
		end, { desc = "Navigate to file 4" })
		keymap.set("n", "<leader>5", function()
			harpoon.ui.nav_file(5)
		end, { desc = "Navigate to file 5" })
		keymap.set("n", "<leader>6", function()
			harpoon.ui.nav_file(6)
		end, { desc = "Navigate to file 6" })
		keymap.set("n", "<leader>7", function()
			harpoon.ui.nav_file(7)
		end, { desc = "Navigate to file 7" })
		keymap.set("n", "<leader>8", function()
			harpoon.ui.nav_file(8)
		end, { desc = "Navigate to file 8" })
		keymap.set("n", "<leader>9", function()
			harpoon.ui.nav_file(9)
		end, { desc = "Navigate to file 9" })

		vim.keymap.set("n", "", function()
			harpoon:list():prev()
		end)
		vim.keymap.set("n", "<leader>l", function()
			harpoon:list():next()
		end)
	end,
}
