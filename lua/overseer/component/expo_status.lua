local active_task_id = nil
local active_task = nil

local function get_config()
  local ok, cfg = pcall(require, "expo-status.config")
  if ok and cfg.get then
    return cfg.get()
  end
  return {
    auto_reload_on_save = true,
  }
end

local function strip_ansi(str)
  local clean = str:gsub("\27%[[0-9;?]*[a-zA-Z]", "")
  clean = clean:gsub("\27%]0;[^\7]*\7", "")
  clean = clean:gsub("\27%([a-zA-Z0-9]", "")
  return vim.trim(clean)
end

local function set_status(new_status)
  if vim.g.expo_runtime_status == new_status then
    return
  end

  vim.g.expo_runtime_status = new_status

  local ok, lualine = pcall(require, "lualine")
  if ok and lualine.refresh then
    vim.schedule(function()
      pcall(lualine.refresh, {
        place = { "statusline" },
      })
    end)
  end
end

local function is_bundle_success(line)
  if line:find("failed", 1, true) or line:find("Failed", 1, true) then
    return false
  end

  local lower = line:lower()

  -- Matches any platform:
  -- "Android Bundled 1420ms", "iOS Bundled 250ms", "Web Bundled 1141ms", "λ Bundled 114ms"
  -- "Bundled 50ms", "Bundled in 120ms", "✓ Bundled"
  if
    lower:match("bundled%s+%d+m?s")
    or lower:match("bundled%s+in%s+%d+")
    or lower:match("✓%s*bundled")
    or lower:match("bundle%s+complete")
    or lower:match("bundle%s+was%s+successfully%s+built")
    or lower:match("finished%s+building%s+javascript%s+bundle")
  then
    return true
  end

  -- Fast Refresh / HMR / Index updates in Expo / React Native
  if
    lower:match("fast%s+refresh")
    or lower:match("reloaded%s+app")
    or lower:match("reloading%s+app")
    or lower:match("›%s*reloading")
    or lower:match("updated%s+%d+%s+path")
  then
    return true
  end

  -- Metro 100% completion indicator (e.g. "100.0% (4373/4373)")
  if
    lower:match("100%.?0?%%%s*%(%s*%d+/%d+%s*%)")
    or lower:match("compiled%s+successfully")
  then
    return true
  end

  return false
end

local function is_error(line)
  local lower = line:lower()
  if
    lower:match("%d+%s+error[s]?")
    or lower:match("no error[s]?")
    or lower:match("error%s*boundar")
  then
    return false
  end

  local exact_phrases = {
    "Unable to resolve module",
    "Unable to resolve",
    "Bundling failed",
    "Metro error",
    "TransformError",
    "Invariant Violation",
    "TypeError",
    "ReferenceError",
    "SyntaxError",
    "RangeError",
    "URIError",
    "Failed to compile",
    "Compilation failed",
    "Failed building JavaScript bundle",
    "Unhandled promise rejection",
  }

  for _, phrase in ipairs(exact_phrases) do
    if line:find(phrase, 1, true) then
      return true
    end
  end

  if
    line:match("^%s*%[ERROR%]%s*")
    or line:match("^%s*ERROR%s*:")
    or line:match("^%s*ERROR%s+")
    or line:match("^%s*Error:%s+")
    or line:match("^%s*error:%s+")
  then
    return true
  end

  return false
end

local function is_metro_ready(line)
  local ready_phrases = {
    "Metro waiting",
    "Waiting on",
    "Logs for your project",
    "Starting Metro Bundler",
    "Metro is running at",
    "Metro ready",
  }
  for _, phrase in ipairs(ready_phrases) do
    if line:find(phrase, 1, true) then
      return true
    end
  end
  if line:match("›%s*Metro%s*waiting") then
    return true
  end
  return false
end

-- Setup auto-clear on file save:
-- When a user saves a file in the active Expo project, any previous error
-- state immediately transitions to "starting" to signal re-evaluation.
-- It also signals Metro to reload and rebuild immediately.
local augroup = vim.api.nvim_create_augroup("ExpoRuntimeStatusSave", { clear = true })
vim.api.nvim_create_autocmd("BufWritePost", {
  group = augroup,
  callback = function(ev)
    if not active_task_id or vim.g.expo_runtime_status ~= "error" then
      return
    end

    local cfg = get_config()
    if not cfg.auto_reload_on_save then
      return
    end

    local file_path = ev.file
    if (not file_path or file_path == "") and ev.buf then
      file_path = vim.api.nvim_buf_get_name(ev.buf)
    end
    if file_path and active_task and active_task.cwd and vim.startswith(file_path, active_task.cwd) then
      set_status("starting")

      -- Signal Metro to reload and rebundle the updated file immediately
      if active_task.strategy and active_task.strategy.job_id then
        pcall(vim.api.nvim_chan_send, active_task.strategy.job_id, "r")
      end
    end
  end,
})

---@type overseer.ComponentFileDefinition
local comp = {
  desc = "Tracks Expo / Metro runtime status and updates Lualine",
  params = {},
  get_active_task = function()
    return active_task
  end,
  constructor = function(params)
    return {
      on_start = function(self, task)
        active_task_id = task.id
        active_task = task
        set_status("starting")
      end,
      on_reset = function(self, task)
        active_task_id = task.id
        active_task = task
        set_status("starting")
      end,
      on_output_lines = function(self, task, lines)
        if active_task_id ~= task.id then
          return
        end

        for _, raw_line in ipairs(lines) do
          -- Split by carriage returns and newlines so terminal overwrites (\r)
          -- are processed as distinct frames in chronological order
          for sub_line in vim.gsplit(raw_line, "[\r\n]", { plain = false }) do
            local clean = strip_ansi(sub_line)
            if clean ~= "" then
              if is_bundle_success(clean) then
                set_status("ok")
              elseif is_error(clean) then
                set_status("error")
              elseif is_metro_ready(clean) then
                if vim.g.expo_runtime_status ~= "error" and vim.g.expo_runtime_status ~= "ok" then
                  set_status("running")
                end
              end
            end
          end
        end
      end,
      on_complete = function(self, task, status, result)
        if active_task_id == task.id then
          active_task_id = nil
          active_task = nil
          set_status(nil)
        end
      end,
      on_dispose = function(self, task)
        if active_task_id == task.id then
          active_task_id = nil
          active_task = nil
          set_status(nil)
        end
      end,
    }
  end,
}

return comp
