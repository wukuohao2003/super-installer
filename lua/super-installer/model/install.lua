local ui = require("super-installer.model.ui")

local M = {}

function M.start(config)
    local plugins = config.install.use
    if #plugins == 0 then return end

    local total = #plugins
    local errors = {}
    local success_count = 0
    local win = ui.create_window("Installing Plugins...", 4, 50)

    for i, plugin in ipairs(plugins) do
        ui.update_progress(win, "Installing: " .. plugin, i, total)
        local ok, err = M.install_plugin(plugin, config.git)
        if ok then
            success_count = success_count + 1
        else
            table.insert(errors, {plugin = plugin, error = err})
        end
    end

    vim.api.nvim_win_close(win.win_id, true)
    ui.show_results(errors, success_count, total, "Installation")
end

function M.install_plugin(plugin, git_type)
    local repo_url
    if git_type == "ssh" then
        repo_url = string.format("git@github.com:%s.git", plugin)
    else
        repo_url = string.format("https://github.com/%s.git", plugin)
    end

    local install_dir = vim.fn.stdpath("data") .. "/site/pack/super-installer/start/" .. plugin:match("/([^/]+)$")

    local cmd = string.format("git clone --depth 1 %s %s 2>&1", repo_url, install_dir)
    local result = vim.fn.system(cmd)
    
    if vim.v.shell_error ~= 0 then
        return false, result:gsub("\n", " "):sub(1, 50) .. "..."
    end
    return true
end

return M