local constants = require("overseer.constants")

local function get_config()
  local ok, cfg = pcall(require, "expo-status.config")
  if ok and cfg.get then
    return cfg.get()
  end
  return {
    node_version = "22",
    nvm_dir = nil,
    package_manager = "auto",
    start_script = "start",
  }
end

---Check if a directory is an Expo project
---@param dir string
---@return boolean
local function is_expo_dir(dir)
  if not dir or dir == "" then
    return false
  end

  for _, cfg in ipairs({ "app.json", "app.config.js", "app.config.ts" }) do
    if vim.uv.fs_stat(vim.fs.joinpath(dir, cfg)) then
      return true
    end
  end

  local pkg_file = vim.fs.joinpath(dir, "package.json")
  if vim.uv.fs_stat(pkg_file) then
    local ok, content = pcall(vim.fn.readfile, pkg_file)
    if ok then
      local text = table.concat(content)
      if text:find('"expo"') or text:find('"expo start"') then
        return true
      end
    end
  end

  return false
end

---Detect package manager for a project directory
---@param dir string
---@param preferred string
---@return string
local function detect_package_manager(dir, preferred)
  if preferred and preferred ~= "auto" then
    return preferred
  end

  -- Check current dir and parents for lockfiles
  local check_dirs = { dir }
  local root = vim.fs.root(dir, { ".git" })
  if root and root ~= dir then
    table.insert(check_dirs, root)
  end

  for _, d in ipairs(check_dirs) do
    if vim.uv.fs_stat(vim.fs.joinpath(d, "pnpm-lock.yaml")) then
      return "pnpm"
    elseif vim.uv.fs_stat(vim.fs.joinpath(d, "yarn.lock")) then
      return "yarn"
    elseif vim.uv.fs_stat(vim.fs.joinpath(d, "bun.lockb")) or vim.uv.fs_stat(vim.fs.joinpath(d, "bun.lock")) then
      return "bun"
    end
  end

  return "npm"
end

---Find Expo project directories within a root (including workspaces and monorepos)
---@param root string
---@return string[]
local function find_expo_dirs(root)
  local results = {}

  if is_expo_dir(root) then
    table.insert(results, root)
    return results
  end

  -- Check pnpm-workspace.yaml if pnpm monorepo
  local pnpm_workspace = vim.fs.joinpath(root, "pnpm-workspace.yaml")
  if vim.uv.fs_stat(pnpm_workspace) then
    local ok, lines = pcall(vim.fn.readfile, pnpm_workspace)
    if ok then
      for _, line in ipairs(lines) do
        local pat = line:match("^%s*-%s*['\"]?([^'\"#%s]+)['\"]?")
        if pat then
          local glob_path = vim.fs.joinpath(root, pat)
          local matches = vim.fn.glob(glob_path, true, true)
          for _, match in ipairs(matches) do
            if vim.fn.isdirectory(match) == 1 and is_expo_dir(match) then
              table.insert(results, match)
            end
          end
        end
      end
    end
  end

  if #results > 0 then
    return results
  end

  -- Check package.json workspaces if monorepo
  local pkg_file = vim.fs.joinpath(root, "package.json")
  if vim.uv.fs_stat(pkg_file) then
    local ok, content = pcall(vim.fn.readfile, pkg_file)
    if ok then
      local ok_json, data = pcall(vim.json.decode, table.concat(content))
      if ok_json and type(data) == "table" and data.workspaces then
        local patterns = type(data.workspaces) == "table" and data.workspaces or {}
        if data.workspaces.packages then
          patterns = data.workspaces.packages
        end
        for _, pat in ipairs(patterns) do
          local glob_path = vim.fs.joinpath(root, pat)
          local matches = vim.fn.glob(glob_path, true, true)
          for _, match in ipairs(matches) do
            if vim.fn.isdirectory(match) == 1 and is_expo_dir(match) then
              table.insert(results, match)
            end
          end
        end
      end
    end
  end

  if #results > 0 then
    return results
  end

  -- Common monorepo subfolder fallback
  local common_paths = {
    "apps/expo",
    "apps/mobile",
    "apps/app",
    "packages/expo",
    "packages/mobile",
    "packages/app",
    "expo",
    "mobile",
    "app",
  }
  for _, sub in ipairs(common_paths) do
    local p = vim.fs.joinpath(root, sub)
    if vim.fn.isdirectory(p) == 1 and is_expo_dir(p) then
      table.insert(results, p)
    end
  end

  return results
end

---Build the command to execute
---@param dir string
---@return string[]
local function build_cmd(dir)
  local cfg = get_config()
  local pm = detect_package_manager(dir, cfg.package_manager)
  local script = cfg.start_script or "start"

  local exec_cmd = string.format("exec %s run %s", pm, script)
  if pm == "yarn" then
    exec_cmd = string.format("exec yarn %s", script)
  end

  if cfg.node_version and cfg.node_version ~= false and cfg.node_version ~= "" then
    local nvm_dir_expr = cfg.nvm_dir and string.format('export NVM_DIR="%s"\n', cfg.nvm_dir)
      or 'export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"\n'

    local script_str = nvm_dir_expr
      .. '[ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"\n'
      .. string.format("nvm use %s\n", tostring(cfg.node_version))
      .. exec_cmd

    return { "bash", "-lc", script_str }
  end

  return { "bash", "-lc", exec_cmd }
end

---@type overseer.TemplateFileProvider
return {
  generator = function(opts)
    local current_file = vim.api.nvim_buf_get_name(0)
    local start_dir = (current_file ~= "" and vim.fs.dirname(current_file))
      or (opts and opts.dir)
      or vim.fn.getcwd()

    -- Check if current file/buffer is already inside an Expo directory
    local buffer_root = vim.fs.root(start_dir, { "package.json" })
    if buffer_root and is_expo_dir(buffer_root) then
      return {
        {
          name = "Expo: start",
          desc = "Start Expo/Metro server with runtime status tracking",
          tags = { constants.TAG.RUN },
          params = {},
          builder = function()
            return {
              name = "Expo: start",
              cmd = build_cmd(buffer_root),
              cwd = buffer_root,
              components = { "default", "expo_status" },
            }
          end,
        },
      }
    end

    -- Look upward for workspace or git root
    local root = vim.fs.root(start_dir, { "package.json", ".git" }) or start_dir
    local expo_dirs = find_expo_dirs(root)

    -- Fallback: if root itself has a start script
    if #expo_dirs == 0 then
      local pkg_file = vim.fs.joinpath(root, "package.json")
      if vim.uv.fs_stat(pkg_file) then
        local ok, content = pcall(vim.fn.readfile, pkg_file)
        if ok and table.concat(content):find('"start"') then
          table.insert(expo_dirs, root)
        end
      end
    end

    if #expo_dirs == 0 then
      return "No Expo project found"
    end

    local tasks = {}
    for _, expo_dir in ipairs(expo_dirs) do
      local task_name = "Expo: start"
      if #expo_dirs > 1 then
        local rel = vim.fs.basename(expo_dir)
        task_name = string.format("Expo: start (%s)", rel)
      end

      table.insert(tasks, {
        name = task_name,
        desc = "Start Expo/Metro server with runtime status tracking",
        tags = { constants.TAG.RUN },
        params = {},
        builder = function()
          return {
            name = task_name,
            cmd = build_cmd(expo_dir),
            cwd = expo_dir,
            components = { "default", "expo_status" },
          }
        end,
      })
    end

    return tasks
  end,
}
