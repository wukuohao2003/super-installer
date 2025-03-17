local M = {}

M.setup = function(user_config)
	local default_config = {
		git = "https",

		install = {
			default = "wukuohao2003/super-installer",
			auto_update = false,
			use = {},
		},

		keymaps = {
			install = "<leader>si",
			remove = "<leader>sr",
			update = "<leader>su",
		},

		ui = {
			progress = {
				icon = "",
			},
			manager = {
				icon = {
					install = "",
					update = "",
					remove = "󰺝",
					check = "󱫁",
					package = "󰏖",
				},
			},
		},
	}

	M.config = vim.tbl_deep_extend("force", default_config, user_config or {})

	vim.api.nvim_create_user_command("SuperInstall", function()
		require("super-installer.model.install").start(M.config)
	end, {})

	vim.api.nvim_create_user_command("SuperRemove", function()
		require("super-installer.model.remove").start(M.config)
	end, {})

	vim.api.nvim_create_user_command("SuperUpdate", function()
		require("super-installer.model.update").start(M.config)
	end, {})

	local keymap_options = { noremap = true, silent = true }
	vim.keymap.set("n", M.config.keymaps.install, "<cmd>SuperInstall<CR>", keymap_options)
	vim.keymap.set("n", M.config.keymaps.remove, "<cmd>SuperRemove<CR>", keymap_options)
	vim.keymap.set("n", M.config.keymaps.update, "<cmd>SuperUpdate<CR>", keymap_options)

	if M.config.install.auto_update then
		vim.api.nvim_create_autocmd("VimEnter", {
			pattern = { "*" },
			callback = function()
				local installer, _ = pcall(vim.fn.execute, "SuperInstall")
				local need_install = require("super-installer.model.install").need_install
				if need_install then
					if not installer then
						vim.notify("Check SuperInstaller status", vim.log.levels.WARN, { title = "SuperInstaller" })
					end
				else
					return false
				end
			end,
		})
	end
end

return M
