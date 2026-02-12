-- leader first
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- ================== BASIC ==================

map("i", "jj", "<Esc>")
map("n", "<leader>q", "<cmd>q!<CR>", opts)
map({ "n", "n" }, "<leader>w", function()
	vim.cmd("w")
end)

-- word wrap toggle
map("n", "<leader>uw", function()
	local wrap = not vim.opt.wrap:get()
	vim.opt.wrap = wrap
	vim.opt.linebreak = wrap
	vim.opt.breakindent = wrap
end, { desc = "Toggle wrap" })

map("n", "<leader>so", vim.cmd.so)

-- ================== VISUAL ==================

map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)
map("v", "p", '"_dp', opts)
map("x", "<leader>p", [["_dP]])

-- ================== SEARCH ==================

map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")
map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "<Esc>", "<cmd>noh<return><esc>", { silent = true })

-- ================== DIAGNOSTICS ==================

map("n", "<leader>dg", vim.diagnostic.open_float, { desc = "Line diagnostics" })

map("n", "<leader>uh", function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle Inlay Hints" })

map("n", "<leader>S", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Rename word under cursor" })

-- ================== TERMINAL RUNNER ==================

local terminals = {}

local function run(cmd, key)
	if terminals[key] and vim.api.nvim_buf_is_valid(terminals[key]) then
		local win = vim.fn.win_findbuf(terminals[key])[1]
		if win then
			vim.api.nvim_set_current_win(win)
		else
			vim.cmd("sb " .. terminals[key])
		end
	else
		vim.cmd("terminal " .. cmd)
		terminals[key] = vim.api.nvim_get_current_buf()
	end
	vim.cmd("startinsert")
end

local function input_run(prompt, base, key, default)
	vim.ui.input({ prompt = prompt, default = default or "" }, function(args)
		if args == nil then
			return
		end
		run(base .. (args ~= "" and " " .. args or ""), key)
	end)
end

map("n", "<leader>tr", function()
	run("cargo run", "cargo_run")
end)
map("n", "<leader>tb", function()
	run("cargo build", "cargo_build")
end)
map("n", "<leader>tt", function()
	input_run("Cargo test args: ", "RUSTFLAGS='-A warnings' cargo test", "cargo_test", "-- --exact --nocapture --quiet")
end)

map("n", "<leader>ma", function()
	input_run("Make args: ", "make", "make")
end)

map("n", "<leader>mi", function()
	run("intercept-build make -j2", "intercept")
end)

map("n", "<leader>mp", function()
	run("npm start", "npm_start")
end)

-- ================== CLIPBOARD ==================

map("n", "<leader>tc", function()
	local current = vim.opt.clipboard:get()
	local on = vim.tbl_contains(current, "unnamedplus")
	vim.opt.clipboard = on and "" or "unnamedplus"
	vim.notify("Clipboard " .. (on and "OFF" or "ON"))
end, { desc = "Toggle clipboard" })

-- ================== TERMINAL ESC ==================

map("t", "<esc><esc>", "<C-\\><C-n>")

-- ================== AUTOCMDS ==================

vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- ================== COMMAND MODE NAV ==================

for k, v in pairs({
	["<Up>"] = 'wildmenumode() ? "\\<Left>"  : "\\<Up>"',
	["<Down>"] = 'wildmenumode() ? "\\<Right>" : "\\<Down>"',
	["<Left>"] = 'wildmenumode() ? "\\<Up>"    : "\\<Left>"',
	["<Right>"] = 'wildmenumode() ? "\\<Down>"  : "\\<Right>"',
}) do
	map("c", k, v, { expr = true, noremap = true })
end

-- ================== SELF UPDATE ==================

vim.api.nvim_create_user_command("FerrisUpdate", function(opts)
	local config_dir = vim.fn.stdpath("config")

	if vim.fn.isdirectory(config_dir .. "/.git") == 0 then
		return vim.notify("Ferris: config is not a git repository", vim.log.levels.ERROR)
	end

	local function git(cmd)
		local cwd = vim.fn.getcwd()
		vim.fn.chdir(config_dir)
		local out = vim.fn.system(cmd)
		local err = vim.v.shell_error
		vim.fn.chdir(cwd)
		return out, err
	end

	--  FETCH ONLY (no working tree touch)
	if opts.args == "fetch" then
		vim.notify("Ferris: fetching updates…")
		local out, err = git({ "git", "fetch", "--quiet" })
		if err ~= 0 then
			return vim.notify("Ferris: fetch failed\n" .. out, vim.log.levels.ERROR)
		end
		return vim.notify("Ferris: fetch complete")
	end

	--  STATUS (ahead / behind / dirty)
	if opts.args == "status" then
		local out = vim.fn.system({
			"git",
			"-C",
			config_dir,
			"status",
			"--short",
			"--branch",
		})
		return vim.notify("Ferris status:\n" .. out)
	end

	--  LOG (recent commits)
	if opts.args == "log" then
		local out = vim.fn.system({
			"git",
			"-C",
			config_dir,
			"log",
			"--oneline",
			"--decorate",
			"-5",
		})
		return vim.notify("Ferris log:\n" .. out)
	end

	--  DEFAULT: SAFE UPDATE
	vim.notify("Ferris: updating configuration…")

	local out, err = git({ "git", "pull", "--ff-only" })
	if err ~= 0 then
		return vim.notify("Ferris: update failed\n" .. out, vim.log.levels.ERROR)
	end

	--  HOT-RELOAD SUPPORT
	pcall(function()
		dofile(config_dir .. "/init.lua")
	end)

	vim.notify("Ferris: update complete · config reloaded")
end, {
	nargs = "?",
	complete = function()
		return { "fetch", "status", "log" }
	end,
})
