local M = {}
local config = require("expo-status.config")

---Generate a Lualine component definition
---@param opts? table
---@return table
function M.component(opts)
  opts = opts or {}
  local label = opts.label
  if label == nil then
    label = "EXPO"
  end

  return {
    function()
      local status = vim.g.expo_runtime_status
      if not status then
        return ""
      end

      local cfg = config.get()
      local icons = opts.icons or cfg.icons or {}
      local icon = icons[status] or ""

      if label and label ~= "" then
        return icon .. label
      end
      return icon
    end,
    cond = function()
      if opts.cond ~= nil then
        return opts.cond()
      end
      return vim.g.expo_runtime_status ~= nil
    end,
    color = function()
      local status = vim.g.expo_runtime_status
      if not status then
        return nil
      end

      local cfg = config.get()
      local colors = opts.colors or cfg.colors or {}
      local hl = colors[status]
      if not hl then
        return nil
      end

      if package.loaded["snacks"] and Snacks.util and Snacks.util.color then
        local fg = Snacks.util.color(hl)
        if fg then
          return { fg = fg }
        end
      end

      return hl
    end,
  }
end

return M
