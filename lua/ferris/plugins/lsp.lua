return {
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			vim.iter({ "c", "cpp", "objc", "objcpp", "json", "jq", "rust", "tex" }):each(function(ft)
				vim.api.nvim_create_autocmd("BufWritePre", {
					pattern = "*." .. ft,
					callback = function()
						vim.lsp.buf.format({ timeout_ms = 1000 })
					end,
				})
			end)

			-- Lua
			vim.lsp.enable("lua_ls", {
				cmd = { "/data/data/com.termux/files/usr/bin/lua-language-server" },
				settings = {
					Lua = {
						diagnostics = { globals = { "vim" } },
						workspace = { checkThirdParty = false },
					},
				},
			})

			-- Clangd
			vim.lsp.enable("clangd", {
				cmd = { "/data/data/com.termux/files/usr/bin/clangd" },
				capabilities = { offsetEncoding = { "utf-16" } },
				initialization_options = {
					clangdFileStatus = true,
					usePlaceholders = true,
					completeUnimported = true,
				},
			})

			-- 3. Global Mappings & Autocmds
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local bufnr = args.buf
					local client = vim.lsp.get_client_by_id(args.data.client_id)

					-- CodeLens
					if client.supports_method("textDocument/codeLens") then
						vim.lsp.codelens.refresh()
						vim.api.nvim_create_autocmd({ "InsertLeave", "BufEnter" }, {
							buffer = bufnr,
							callback = vim.lsp.codelens.refresh,
						})
					end

					-- Semantic Tokens
					vim.keymap.set("n", "<Leader>uY", function()
						vim.lsp.semantic_tokens.stop(bufnr, client.id)
					end, { buffer = bufnr, desc = "Toggle Semantic Tokens" })

					vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr })
				end,
			})
		end,
	},
}
