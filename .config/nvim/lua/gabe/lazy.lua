local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	{ import = "gabe.plugins" },
	{ import = "gabe.plugins.lsp" },
	{ import = "gabe.plugins.mini" },
	{ import = "gabe.plugins.note" },
	{ import = "gabe.plugins.debug" },
	{ import = "gabe.plugins.python" },
}, {
	-- No plugin here needs luarocks, and leaving it enabled makes
	-- `:checkhealth lazy` report a hererocks install it will never use.
	rocks = { enabled = false },
	checker = {
		enabled = true,
		notify = false,
	},
	change_detection = {
		notify = false,
	},
})
