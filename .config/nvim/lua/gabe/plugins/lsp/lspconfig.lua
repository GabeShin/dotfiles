return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
		{
			-- Replaces the archived folke/neodev.nvim.
			"folke/lazydev.nvim",
			ft = "lua",
			opts = {
				library = {
					{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				},
			},
		},
	},
	config = function()
		local keymap = vim.keymap -- for conciseness

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				-- Buffer local mappings.
				-- See `:help vim.lsp.*` for documentation on any of the below functions
				local opts = { buffer = ev.buf, silent = true }

				-- set keybinds
				opts.desc = "Show LSP references"
				keymap.set("n", "gr", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references

				-- `textDocument/declaration` is implemented by almost no server
				-- (not pyright, ts_ls or lua_ls), so asking for a declaration
				-- printed "method ... is not supported by any server" on every
				-- press. Definition is what this key was always meant to do.
				opts.desc = "Go to definition"
				keymap.set("n", "gd", vim.lsp.buf.definition, opts) -- go to definition

				opts.desc = "Show LSP definitions"
				keymap.set("n", "gD", "<cmd>Telescope lsp_definitions<CR>", opts) -- show lsp definitions

				opts.desc = "Show LSP implementations"
				keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts) -- show lsp implementations

				opts.desc = "Show LSP type definitions"
				keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts) -- show lsp type definitions

				opts.desc = "See available code actions"
				keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection

				opts.desc = "Smart rename"
				keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts) -- smart rename

				opts.desc = "Show buffer diagnostics"
				keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file

				opts.desc = "Show line diagnostics"
				keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line

				-- vim.diagnostic.goto_prev/goto_next are deprecated and go away
				-- in Neovim 0.13; vim.diagnostic.jump() replaces both.
				opts.desc = "Go to previous diagnostic"
				keymap.set("n", "[d", function()
					vim.diagnostic.jump({ count = -1, float = true })
				end, opts) -- jump to previous diagnostic in buffer

				opts.desc = "Go to next diagnostic"
				keymap.set("n", "]d", function()
					vim.diagnostic.jump({ count = 1, float = true })
				end, opts) -- jump to next diagnostic in buffer

				opts.desc = "Show documentation for what is under cursor"
				keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor

				opts.desc = "Restart LSP"
				keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts) -- mapping to restart lsp if necessary
			end,
		})

		-- Diagnostic symbols in the sign column (gutter).
		-- Defining these with vim.fn.sign_define() is the pre-0.10 way; the
		-- diagnostic handler owns its own signs now and this is the only
		-- supported place to set their text.
		vim.diagnostic.config({
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = " ",
					[vim.diagnostic.severity.WARN] = " ",
					[vim.diagnostic.severity.HINT] = "󰠠 ",
					[vim.diagnostic.severity.INFO] = " ",
				},
			},
		})

		-- Two separate ruff problems, both fixed here.
		--
		-- ruff logs every INFO line to stderr, and Neovim records a server's
		-- stderr at ERROR level regardless of content -- which is how lsp.log
		-- grew to 40MB. logLevel silences it at the source rather than
		-- filtering it afterwards.
		--
		-- ruff also *panics* on a document whose URI has no parent directory,
		-- printing three notifications per occurrence ("exited with a panic",
		-- "encountered a problem", "-32603 ... a path to a document should
		-- have a parent path"). A nameless buffer set to filetype=python is
		-- exactly that document. Declining to hand back a root directory is
		-- the documented way to say "do not start here", and it stops the
		-- request being made at all -- detaching afterwards would be too late,
		-- didOpen has already gone out.
		vim.lsp.config("ruff", {
			init_options = { settings = { logLevel = "error" } },
			root_dir = function(bufnr, on_dir)
				if vim.api.nvim_buf_get_name(bufnr) == "" then
					return -- no on_dir() call => ruff is not started for this buffer
				end
				on_dir(vim.fs.root(bufnr, { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" }) or vim.fn.getcwd())
			end,
		})
	end,
}
