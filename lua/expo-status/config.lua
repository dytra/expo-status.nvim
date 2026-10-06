local M = {}

---@class ExpoStatusConfig
---@field node_version? string|number|false Node.js version to use with nvm (default: "22", false to skip nvm)
---@field nvm_dir? string Path to NVM directory (default: "$NVM_DIR" or "$HOME/.nvm")
---@field package_manager? "auto"|"npm"|"pnpm"|"yarn"|"bun" Package manager to run start command (default: "auto")
---@field start_script? string Script name to run in package.json (default: "start")
---@field auto_reload_on_save? boolean Automatically send 'r' to Metro and transition to "starting" upon file save during error (default: true)
---@field enable_user_command? boolean Whether to register :ExpoReload command (default: true)
---@field icons? table<string, string> Status indicator icons
---@field colors? table<string, string> Diagnostic highlight groups for statusline

M.defaults = {
  node_version = "22",
  nvm_dir = nil,
  package_manager = "auto",
  start_script = "start",
  auto_reload_on_save = true,
  enable_user_command = true,
  icons = {
    starting = "󰑮 ",
    running = "● ",
    ok = " ",
    error = " ",
  },
  colors = {
    starting = "DiagnosticWarn",
    running = "DiagnosticInfo",
    ok = "DiagnosticOk",
    error = "DiagnosticError",
  },
}

M.options = vim.deepcopy(M.defaults)

---Configure plugin options
---@param user_opts? table
---@return table
function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
  return M.options
end

---Get current options
---@return table
function M.get()
  return M.options
end

return M
