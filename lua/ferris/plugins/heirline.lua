return {
	"rebelot/heirline.nvim",
	event = "UiEnter",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"lewis6991/gitsigns.nvim",
	},
	config = function()
		local heirline = require("heirline")
		local conditions = require("heirline.conditions")
		local utils = require("heirline.utils")

		-- Colors
		local function setup_colors()
			local get_hl = utils.get_highlight
			local function get_safe(group, prop, fallback)
				local hl = get_hl(group)
				return (hl and hl[prop]) and hl[prop] or fallback
			end

			return {
				bright_bg = get_safe("CursorLine", "bg", "#292e42"),
				bright_fg = get_safe("Normal", "fg", "#c0caf5"),
				normal_bg = get_safe("StatusLine", "bg", "#16161e"),
				normal_fg = get_safe("StatusLine", "fg", "#a9b1d6"),
				red = get_safe("DiagnosticError", "fg", "#f7768e"),
				green = get_safe("String", "fg", "#9ece6a"),
				blue = get_safe("Function", "fg", "#7aa2f7"),
				gray = get_safe("NonText", "fg", "#565f89"),
				orange = get_safe("Constant", "fg", "#ff9e64"),
				purple = get_safe("Statement", "fg", "#bb9af7"),
				cyan = get_safe("Special", "fg", "#7dcfff"),
				diag_warn = get_safe("DiagnosticWarn", "fg", "#e0af68"),
				diag_error = get_safe("DiagnosticError", "fg", "#db4b4b"),
				diag_hint = get_safe("DiagnosticHint", "fg", "#1abc9c"),
				diag_info = get_safe("DiagnosticInfo", "fg", "#0db9d7"),
				git_del = get_safe("GitSignsDelete", "fg", "#db4b4b"),
				git_add = get_safe("GitSignsAdd", "fg", "#41a6b5"),
				git_change = get_safe("GitSignsChange", "fg", "#e0af68"),
			}
		end

		vim.api.nvim_create_autocmd("ColorScheme", {
			callback = function()
				utils.on_colorscheme(setup_colors)
			end,
		})

		-- KEYPRESS VISUAL FEEDBACK

		local kb_state = {
			keys = {},
			max = 2,
		}

		local function push_key(key)
			table.insert(kb_state.keys, key)
			if #kb_state.keys > kb_state.max then
				table.remove(kb_state.keys, 1)
			end
			vim.api.nvim__redraw({ statusline = true })
		end

		local function reset_keys()
			kb_state.keys = {}
			vim.api.nvim__redraw({ statusline = true })
		end

		-- Capture only Normal mode keymaps instead of global on_key
		vim.api.nvim_create_autocmd("ModeChanged", {
			callback = function()
				if vim.fn.mode() ~= "n" then
					reset_keys()
				end
			end,
		})

		-- Use mapping wrapper for normal mode keys
		local ns = vim.api.nvim_create_namespace("heirline_keypress_clean")

		local timer = nil
		local timeout = 1200 -- milliseconds before clearing

		local function start_timer()
			if timer then
				timer:stop()
				timer:close()
			end

			timer = vim.loop.new_timer()
			timer:start(
				timeout,
				0,
				vim.schedule_wrap(function()
					reset_keys()
				end)
			)
		end

		vim.on_key(function(key)
			local mode = vim.fn.mode()

			if mode ~= "n" then
				return
			end

			local k = vim.fn.keytrans(key)
			if not k or k == "" then
				return
			end

			if k:sub(1, 1) == "<" then
				return
			end

			if #k > 1 or k:byte() < 32 then
				return
			end

			if k:find("Mouse") or k:find("Scroll") or k:find("Drag") or k:find("Release") then
				return
			end

			push_key(k)
			start_timer()
		end, ns)

		local KeypressFeedback = {
			condition = function()
				return vim.fn.mode() == "n" and #kb_state.keys > 0
			end,
			provider = function()
				return " " .. table.concat(kb_state.keys, "") .. " "
			end,
			hl = { fg = "cyan", bg = "bright_bg", bold = true },
		}

		-- COMPONENTS & HELPERS
		local Space = { provider = " " }
		local Align = { provider = "%=" }

		-- Vi Mode
		local ViMode = {
			init = function(self)
				self.mode = vim.fn.mode(1)
			end,
			on_click = {
				callback = function()
					vim.defer_fn(function()
						vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(":", true, false, true), "n", true)
					end, 50)
				end,
				name = "sl_mode_click",
			},
			static = {
				mode_names = {
					n = "󰈚 ", -- normal
					v = "󰈈 ", -- visual
					V = "󰈈 ", -- visual line
					["\22"] = "󰈈 ", -- visual block
					s = "󰒅 ", -- select
					S = "󰒅 ", -- select line
					i = "󰏫 ", -- insert
					R = "󰑖 ", -- replace
					c = "󰘳 ", -- command
					t = "󰆍 ", -- terminal
				},
				mode_colors = {
					n = "blue",
					i = "green",
					v = "purple",
					V = "purple",
					["\22"] = "purple",
					c = "orange",
					s = "purple",
					R = "red",
					r = "red",
					["!"] = "red",
					t = "red",
				},
			},
			{
				provider = "",
				hl = function(self)
					local mode_char = self.mode:sub(1, 1)
					return { fg = self.mode_colors[mode_char] or "purple", bg = "normal_bg" }
				end,
			},
			{
				provider = function(self)
					return "" .. (self.mode_names[self.mode] or self.mode)
				end,
				hl = function(self)
					local mode_char = self.mode:sub(1, 1)
					return { fg = "normal_bg", bg = self.mode_colors[mode_char] or "purple", bold = true }
				end,
			},
			{
				provider = "",
				hl = function(self)
					local mode_char = self.mode:sub(1, 1)
					local is_keypress = (vim.fn.mode() == "n" and #kb_state.keys > 0)
					local is_macro = (vim.fn.reg_recording() ~= "")

					local bg_color = (is_keypress or is_macro) and "bright_bg" or "normal_bg"

					return { fg = self.mode_colors[mode_char] or "purple", bg = bg_color }
				end,
			},
		}

		-- Macro Recorder
		local MacroRecorder = {
			condition = function()
				return vim.fn.reg_recording() ~= ""
			end,
			update = { "RecordingEnter", "RecordingLeave" },

			provider = function()
				return " 󰑋 @" .. vim.fn.reg_recording() .. " "
			end,

			hl = { fg = "orange", bg = "bright_bg", bold = true },
		}

		-- Git Status
		local Git = {
			condition = conditions.is_git_repo,

			init = function(self)
				local status = vim.b.gitsigns_status_dict or {}
				self.added = status.added or 0
				self.removed = status.removed or 0
				self.changed = status.changed or 0
				self.head = status.head or ""
			end,
			on_click = {
				callback = function()
					vim.defer_fn(function()
						Snacks.picker.git_log_file()
					end, 100)
				end,
				name = "sl_git_click",
			},
		}

		local GitAdded = {
			condition = function(self)
				return self.added > 0
			end,
			provider = function(self)
				return " " .. self.added .. " "
			end,
			hl = "GitSignsAdd",
		}

		local GitChanged = {
			condition = function(self)
				return self.changed > 0
			end,
			provider = function(self)
				return " " .. self.changed .. " "
			end,
			hl = "GitSignsChange",
		}

		local GitRemoved = {
			condition = function(self)
				return self.removed > 0
			end,
			provider = function(self)
				return " " .. self.removed .. " "
			end,
			hl = "GitSignsDelete",
		}

		local GitBranch = {
			provider = function(self)
				return (self.head ~= "" and (" " .. self.head .. " ")) or ""
			end,
			hl = { fg = "purple", bold = true },
		}

		Git[1] = {
			flexible = 3,

			-- FULL
			{ GitAdded, GitChanged, GitRemoved, GitBranch },

			-- MEDIUM (no branch)
			{ GitAdded, GitChanged, GitRemoved },

			-- MINIMAL
			{ provider = " ", hl = { fg = "purple" } },
		}

		-- File Extension / Name
		local FileBlock = {
			init = function(self)
				self.filename = vim.api.nvim_buf_get_name(0)
			end,
			on_click = {
				callback = function()
					vim.defer_fn(function()
						vim.api.nvim_feedkeys(
							vim.api.nvim_replace_termcodes("<leader>e", true, false, true),
							"m",
							false
						)
					end, 50)
				end,
				name = "sl_file_click",
			},

			-- Icon Component
			{
				init = function(self)
					local filename = self.filename
					local extension = vim.fn.fnamemodify(filename, ":e")
					self.icon, self.icon_color =
						require("nvim-web-devicons").get_icon_color(filename, extension, { default = true })
				end,
				provider = function(self)
					return self.icon and (self.icon .. " ")
				end,
				hl = function(self)
					return { fg = self.icon_color }
				end,
			},

			{
				flexible = 1,
				{
					provider = function(self)
						local name = vim.fn.fnamemodify(self.filename, ":t")
						if name == "" then
							return "[No Name] "
						end
						return name .. " "
					end,
					hl = { fg = "bright_fg", bold = true },
				},
				{
					provider = function(self)
						local ext = vim.fn.fnamemodify(self.filename, ":e")
						if ext == "" then
							return ""
						end
						return "." .. ext .. " "
					end,
					hl = { fg = "bright_fg", bold = true },
				},
				{
					provider = "",
				},
			},
		}

		local FileFlags = {
			{
				condition = function()
					return vim.bo.modified
				end,
				provider = "● ",
				hl = { fg = "green" },
			},
			{
				condition = function()
					return not vim.bo.modifiable or vim.bo.readonly
				end,
				provider = " ",
				hl = { fg = "red" },
			},
		}

		-- Diagnostics
		local Diagnostics = {
			condition = conditions.has_diagnostics,

			static = {
				signs = {
					{ name = "errors", severity = vim.diagnostic.severity.ERROR, icon = " ", hl = "diag_error" },
					{ name = "warnings", severity = vim.diagnostic.severity.WARN, icon = " ", hl = "diag_warn" },
					{ name = "hints", severity = vim.diagnostic.severity.HINT, icon = " ", hl = "diag_hint" },
				},
			},

			init = function(self)
				for _, s in ipairs(self.signs) do
					self[s.name] = #vim.diagnostic.get(0, { severity = s.severity })
				end
			end,

			update = { "DiagnosticChanged", "BufEnter" },

			on_click = {
				name = "sl_diagnostics_click",
				callback = function()
					vim.defer_fn(function()
						vim.diagnostic.setqflist({ open = true })
					end, 50)
				end,
			},
		}

		-- generate providers dynamically
		for _, s in ipairs(Diagnostics.static.signs) do
			table.insert(Diagnostics, {
				provider = function(self)
					local count = self[s.name]
					return count > 0 and (s.icon .. count .. " ") or ""
				end,
				hl = { fg = s.hl },
			})
		end

		-- LSP Active
		local LSPActive = {
			condition = conditions.lsp_attached,
			update = { "LspAttach", "LspDetach" },

			init = function(self)
				local clients = vim.lsp.get_clients({ bufnr = 0 })
				self.clients = clients
				self.client_name = clients[1] and clients[1].name or ""
			end,

			on_click = {
				callback = function()
					local bufnr = vim.api.nvim_get_current_buf()
					local clients = vim.lsp.get_clients({ bufnr = bufnr })
					if #clients == 0 then
						return
					end

					for _, client in ipairs(clients) do
						local config = client.config
						local name = client.name

						client.stop()

						vim.defer_fn(function()
							local new_id = vim.lsp.start(config)
							if new_id then
								vim.notify("Restarted " .. name, vim.log.levels.INFO)
							end
						end, 200)
					end
				end,
				name = "sl_lsp_click",
			},

			flexible = 2,

			-- Name (auto truncate properly)
			{
				provider = function(self)
					if self.client_name == "" then
						return ""
					end

					local max = 6
					local name = self.client_name
					if #name > max then
						name = name:sub(1, max) .. "…"
					end

					return " " .. name .. " "
				end,
				hl = { fg = "green", bold = true },
			},

			-- Icon fallback
			{
				provider = " ",
				hl = { fg = "green" },
			},
		}

		-- Ruler
		local Ruler = {
			on_click = {
				callback = function()
					vim.defer_fn(function()
						vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(":<C-u>", true, false, true), "n", true)
					end, 50)
				end,
				name = "sl_ruler_click",
			},
			{
				provider = "",
				hl = function()
					local mode_char = vim.fn.mode():sub(1, 1)
					return { fg = ViMode.static.mode_colors[mode_char] or "purple", bg = "normal_bg" }
				end,
			},
			{
				hl = function()
					local mode_char = vim.fn.mode():sub(1, 1)
					return { fg = "normal_bg", bg = ViMode.static.mode_colors[mode_char] or "purple" }
				end,
				{ provider = " " },
				{
					provider = function()
						return string.format("%d:%-2d", vim.fn.line("."), vim.fn.col("."))
					end,
				},
				{ provider = " │ " },
				{
					provider = function()
						local current = vim.fn.line(".")
						local total = vim.fn.line("$")
						if current == 1 then
							return "Top "
						end
						if current == total then
							return "Bot "
						end
						return math.floor((current / total) * 100) .. "%% "
					end,
				},
			},
			{
				provider = "",
				hl = function()
					local mode_char = vim.fn.mode():sub(1, 1)
					return { fg = ViMode.static.mode_colors[mode_char] or "purple", bg = "normal_bg" }
				end,
			},
		}

		local VisualFeedbackBlock = {
			{
				condition = function()
					return (vim.fn.mode() == "n" and #kb_state.keys > 0) or (vim.fn.reg_recording() ~= "")
				end,

				{
					condition = function()
						return #kb_state.keys > 0
					end,
					KeypressFeedback,
					{
						condition = function()
							return vim.fn.reg_recording() ~= ""
						end,
						provider = "│",
						hl = { fg = "gray", bg = "bright_bg" },
					},
				},

				{
					condition = function()
						return vim.fn.reg_recording() ~= ""
					end,
					MacroRecorder,
				},

				{
					provider = "",
					hl = { fg = "bright_bg", bg = "normal_bg" },
				},
			},
		}

		-- BUILD STATUSLINE
		local StatusLine = {
			hl = { bg = "normal_bg" },
			ViMode,
			VisualFeedbackBlock,
			Space,
			Git,
			Align,
			FileBlock,
			FileFlags,
			Align,
			Diagnostics,
			LSPActive,
			Space,
			Ruler,
		}

		heirline.setup({
			statusline = StatusLine,
			opts = { colors = setup_colors },
		})
	end,
}
