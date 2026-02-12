return {
	"saghen/blink.cmp",
	dependencies = "rafamadriz/friendly-snippets",
	version = "*",

	opts = {
		keymap = { preset = "enter" },

		appearance = {
			use_nvim_cmp_as_default = true,
			nerd_font_variant = "mono",
		},

		completion = {
			-- Show documentation when selecting a completion item
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 200,
				window = { border = "rounded" },
			},

			-- Customize the completion menu appearance
			menu = {
				border = "rounded",
				draw = {
					columns = { { "kind_icon" }, { "label", "label_description", gap = 1 } },
				},
			},
		},

		signature = { enabled = true, window = { border = "rounded" } },

		sources = {
			default = { "lsp", "path", "snippets", "buffer" },
		},
	},
}
