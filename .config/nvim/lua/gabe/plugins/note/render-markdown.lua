-- Define the Kanagawa colors table with comments explaining each color.
local kanagawa_colors = {
	fujiWhite = "#DCD7BA", -- Default foreground
	oldWhite = "#C8C093", -- Dark foreground (statuslines)
	sumiInk0 = "#16161D", -- Dark background (statuslines and floating windows)
	sumiInk1 = "#1F1F28", -- Default background
	sumiInk2 = "#2A2A37", -- Lighter background (colorcolumn, folds)
	sumiInk3 = "#363646", -- Lighter background (cursorline)
	sumiInk4 = "#54546D", -- Darker foreground (line numbers, fold column, non-text characters), float borders
	waveBlue1 = "#223249", -- Popup background, visual selection background
	waveBlue2 = "#2D4F67", -- Popup selection background, search background
	winterGreen = "#2B3328", -- Diff Add (background)
	winterYellow = "#49443C", -- Diff Change (background)
	winterRed = "#43242B", -- Diff Deleted (background)
	winterBlue = "#252535", -- Diff Line (background)
	autumnGreen = "#76946A", -- Git Add
	autumnRed = "#C34043", -- Git Delete
	autumnYellow = "#DCA561", -- Git Change
	samuraiRed = "#E82424", -- Diagnostic Error
	roninYellow = "#FF9E3B", -- Diagnostic Warning
	waveAqua1 = "#6A9589", -- Diagnostic Info
	dragonBlue = "#658594", -- Diagnostic Hint
	fujiGray = "#727169", -- Comments
	springViolet1 = "#938AA9", -- Light foreground
	oniViolet = "#957FB8", -- Statements and Keywords
	crystalBlue = "#7E9CD8", -- Functions and Titles
	springViolet2 = "#9CABCA", -- Brackets and punctuation
	springBlue = "#7FB4CA", -- Specials and builtin functions
	lightBlue = "#A3D4D5", -- Not used
	waveAqua2 = "#7AA89F", -- Types
	springGreen = "#98BB6C", -- Strings
	boatYellow1 = "#938056", -- Not used
	boatYellow2 = "#C0A36E", -- Operators, RegEx
	carpYellow = "#E6C384", -- Identifiers
	sakuraPink = "#D27E99", -- Numbers
	waveRed = "#E46876", -- Standout specials 1 (builtin variables)
	peachRed = "#FF5D62", -- Standout specials 2 (exception handling, return)
	surimiOrange = "#FFA066", -- Constants, imports, booleans
	katanaGray = "#717C7C", -- Deprecated
}

return {
	"MeanderingProgrammer/render-markdown.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		render_modes = true,
		completions = { lsp = { enabled = true } },
		heading = {
			position = "inline",
		},
		code = {
			width = "full",
			left_pad = 4,
			right_pad = 4,
			border = "thick",
		},
		checkbox = { checked = { scope_highlight = "@markup.strikethrough" } },
	},
	config = function(_, opts)
		-- Headings
		vim.api.nvim_set_hl(0, "RenderMarkdownH1", { fg = "#6893bf", bg = "None", italic = false })
		vim.api.nvim_set_hl(0, "RenderMarkdownH1Bg", { fg = "#6893bf", bg = "None", italic = false })
		vim.api.nvim_set_hl(0, "RenderMarkdownH2", { fg = "#e8702a", bg = "None", italic = false })
		vim.api.nvim_set_hl(0, "RenderMarkdownH2Bg", { fg = "#e8702a", bg = "None", italic = false })
		vim.api.nvim_set_hl(0, "RenderMarkdownH3", { fg = "#80a665", bg = "None", italic = false })
		vim.api.nvim_set_hl(0, "RenderMarkdownH3Bg", { fg = "#80a665", bg = "None", italic = false })
		vim.api.nvim_set_hl(0, "RenderMarkdownH4", { fg = "#4c9a91", bg = "None", italic = false })
		vim.api.nvim_set_hl(0, "RenderMarkdownH4Bg", { fg = "#4c9a91", bg = "None", italic = false })
		vim.api.nvim_set_hl(0, "RenderMarkdownH5", { fg = "#d3869b", bg = "None", italic = false })
		vim.api.nvim_set_hl(0, "RenderMarkdownH5Bg", { fg = "#d3869b", bg = "None", italic = false })
		vim.api.nvim_set_hl(0, "RenderMarkdownH6", { fg = "#d3869b", bg = "None", italic = false })
		vim.api.nvim_set_hl(0, "RenderMarkdownH6Bg", { fg = "#d3869b", bg = "None", italic = false })

		-- Code blocks
		vim.api.nvim_set_hl(0, "RenderMarkdownCode", { fg = "None", bg = kanagawa_colors.sumiInk0, italic = false })

		-- Dashed Lines
		vim.api.nvim_set_hl(0, "RenderMarkdownDash", { fg = kanagawa_colors.surimiOrange, bg = "None", italic = false })
		require("render-markdown").setup(opts)
	end,
}
