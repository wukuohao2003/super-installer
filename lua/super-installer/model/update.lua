local ui = require("super-installer.model.ui")
local utils = require("super-installer.model.utils")

local M = {}

local is_update_aborted = false
local update_win = nil
local jobs = {}

local plugins_to_update = {}

function M.start(config)
	is_update_aborted = false
	plugins_to_update = {}
	jobs = {}

	local plugins = config.install.packages
	table.insert(plugins, 1, config.install.default)
	plugins = utils.table_duplicates(plugins)

	if #plugins == 0 then
		ui.log_message("Noting to update ...")
		return
	end

	local total = #plugins
	local errors = {}
	local success_count = 0
	local progress_win_check = ui.create_window("Checking Plugins", 68)

	vim.api.nvim_create_autocmd("WinClosed", {
		buffer = progress_win_check.buf,
		callback = function()
			for _, job in ipairs(jobs) do
				vim.fn.jobstop(job)
			end
			is_update_aborted = true
		end,
	})

	local function update_next_plugin(index, win)
		if is_update_aborted or index > #plugins_to_update then
			local msg = is_update_aborted and "Stop" or "Success"
			ui.update_progress(win, msg, #plugins_to_update, #plugins_to_update, config.ui)
			vim.defer_fn(function()
				vim.api.nvim_win_close(win.win_id, true)
				ui.show_report(errors, success_count, #plugins_to_update, "Update")
			end, 100)
			return
		end

		local plugin = plugins_to_update[index]
		ui.update_progress(
			win,
			config.ui.manager.icon.update .. " Updating: " .. plugin,
			index,
			#plugins_to_update,
			config.ui
		)

		M.update_plugin(plugin, config.install.package_path, function(ok, err)
			if ok then
				success_count = success_count + 1
			else
				table.insert(errors, { plugin = plugin, error = err })
			end
			update_next_plugin(index + 1, win)
		end)
	end

	local function check_next_plugin(index, win)
		if is_update_aborted or index > total then
			if #plugins_to_update == 0 and #errors == 0 then
				vim.api.nvim_win_close(win.win_id, true)
				ui.log_message("All Plugins is already up-to-date")
			elseif not is_update_aborted then
				update_win = ui.create_window("Updating", 68)
				vim.api.nvim_create_autocmd("WinClosed", {
					buffer = update_win.buf,
					callback = function()
						is_update_aborted = true
						for _, job in ipairs(jobs) do
							vim.fn.jobstop(job)
						end
					end,
				})
				update_next_plugin(1, update_win)
			end
			return
		end

		local plugin = plugins[index]
		ui.update_progress(
			progress_win_check,
			config.ui.manager.icon.check .. " Checking: " .. plugin,
			index,
			total,
			config.ui
		)

		M.check_plugin(plugin, config.install.package_path, function(ok, result)
			if ok and result == "need_update" then
				table.insert(plugins_to_update, plugin)
			elseif not ok then
				table.insert(errors, { plugin = plugin, error = result })
			end
			check_next_plugin(index + 1, progress_win_check)
		end)
	end

	check_next_plugin(1, progress_win_check)
end

function M.check_plugin(plugin, package_path, callback)
	if is_update_aborted then
		return callback(false, "Stop")
	end

	local install_dir = utils.get_install_dir(plugin, "update", package_path)
	if vim.fn.isdirectory(install_dir) ~= 1 then
		return callback(false, "Directory is not found")
	end

	local fetch_cmd = string.format("cd %s && git fetch --quiet", install_dir)
	local check_cmd = string.format("cd %s && git rev-list --count HEAD..@{upstream} 2>&1", install_dir)

	local job = utils.execute_command(fetch_cmd, function(fetch_ok, _)
		if not fetch_ok then
			return callback(false, "Warehouse synchronization failed")
		end

		utils.execute_command(check_cmd, function(_, result)
			local count = tonumber(result:match("%d+"))
			if count and count > 0 then
				callback(true, "need_update")
			else
				callback(true, "already_updated")
			end
		end)
	end)
	table.insert(jobs, job)
end

function M.update_plugin(plugin, package_path, callback)
	if is_update_aborted then
		return callback(false, "Stop")
	end

	local install_dir = utils.get_install_dir(plugin, "update", package_path)
	local cmd = string.format("cd %s && git pull --quiet && git submodule update --init --recursive", install_dir)

	local job = utils.execute_command(cmd, function(ok, output)
		callback(ok, ok and "Success" or output)
	end)
	table.insert(jobs, job)
end

return M
