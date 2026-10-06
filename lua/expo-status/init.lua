local M = {}
local config = require("expo-status.config")

---Setup expo-status.nvim
---@param opts? ExpoStatusConfig
function M.setup(opts)
  local cfg = config.setup(opts)

  if cfg.enable_user_command then
    pcall(vim.api.nvim_create_user_command, "ExpoReload", function()
      M.reload()
    end, { desc = "Trigger Metro reload in active Expo task" })
  end
end

---Get current runtime status string ("starting" | "running" | "ok" | "error" | nil)
---@return string|nil
function M.get_status()
  return vim.g.expo_runtime_status
end

---Set runtime status and notify statusline listeners
---@param new_status string|nil
function M.set_status(new_status)
  if vim.g.expo_runtime_status == new_status then
    return
  end

  vim.g.expo_runtime_status = new_status

  local ok, lualine = pcall(require, "lualine")
  if ok and lualine.refresh then
    vim.schedule(function()
      pcall(lualine.refresh, { place = { "statusline" } })
    end)
  end
end

---Send reload 'r' to the active Expo task
function M.reload()
  local ok, comp = pcall(require, "overseer.component.expo_status")
  local task = ok and comp.get_active_task and comp.get_active_task()
  if task and task.strategy and task.strategy.job_id then
    pcall(vim.api.nvim_chan_send, task.strategy.job_id, "r")
    vim.notify("Triggered Expo/Metro reload (r)", vim.log.levels.INFO, { title = "Expo" })
  else
    vim.notify("No active Expo task running", vim.log.levels.WARN, { title = "Expo" })
  end
end

---Generate a Lualine component spec
---@param opts? table
---@return table
function M.lualine(opts)
  return require("expo-status.lualine").component(opts)
end

return M
