return {
	"github/copilot.vim",
	config = function()
		vim.g.copilot_filetypes = {
			["*"] = false,
			["css"] = true,
			["html"] = true,
			["javascript"] = true,
			["typescript"] = true,
			["javascriptreact"] = true,
			["typescriptreact"] = true,
			["lua"] = true,
			["rust"] = true,
			["c"] = true,
			["c#"] = true,
			["c++"] = true,
			["go"] = true,
			["python"] = true,
		}
	end,
}
