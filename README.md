# expo-status.nvim

> Real-time Expo & React Native Metro runtime status tracking for Neovim ([Overseer](https://github.com/stevearc/overseer.nvim) + [Lualine](https://github.com/nvim-lualine/lualine.nvim)).

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Neovim](https://img.shields.io/badge/Neovim-0.10+-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Overseer.nvim](https://img.shields.io/badge/Overseer.nvim-compatible-blueviolet)](https://github.com/stevearc/overseer.nvim)
[![Lualine.nvim](https://img.shields.io/badge/Lualine.nvim-compatible-informational)](https://github.com/nvim-lualine/lualine.nvim)

---

## 💡 Why This Plugin?

When running Expo / React Native in background task runners like Overseer:

```text
Metro process status: RUNNING
Expo app state:       ERROR (SyntaxError / ModuleResolution / InvariantViolation)
```

Overseer only tracks the **process exit code**. Because Metro stays alive and waits for fixes, standard task status remains `RUNNING`, leaving you completely blind to syntax errors, import failures, and build crashes until you switch windows or open logs.

**`expo-status.nvim`** bridges this gap:
1. It intercepts Metro stdout/stderr streams in real time.
2. It tracks bundling lifecycles across platforms (**Android**, **iOS**, **Web**, and Expo Router **`λ Bundled`** server routes).
3. It immediately reflects errors in your Neovim statusline with diagnostic highlights.
4. When you fix the bug and save (`:w`), it automatically clears the error state and triggers Metro reload (`r`)!

---

## 🎯 Statusline Indicator

```text
NORMAL │  main │ app/index.tsx │  EXPO │ typescript │ 34:12
```

| State | Indicator | Description |
|---|---|---|
| **Starting** | `󰑮 EXPO` | Metro server is booting up or rebundling |
| **Running** | `● EXPO` | Metro bundler is active and waiting for connections |
| **Ok** | ` EXPO` | Bundle completed successfully (Android, iOS, Web, λ routes) |
| **Error** | ` EXPO` | Syntax error, module resolution failure, or runtime crash |
| **Stopped** | *(hidden)* | Task stopped or disposed |

---

## ✨ Features

- **⚡ Live Stream Parsing**: Handles ANSI escape codes and `\r` carriage return terminal overwrite animations in chronological order.
- **🔄 Auto Rebuild on Save**: Saving a file in the project directory while in error state automatically signals Metro to rebundle (`r`) and clears the sticky error.
- **🏗️ Monorepo & Workspace Aware**: Automatically detects Expo projects inside `pnpm-workspace.yaml`, `package.json` `workspaces`, or standard monorepo layouts (`apps/expo`, `apps/mobile`, etc.).
- **🟢 NVM / Node Version Management**: Runs tasks with a specific Node version (e.g. Node 22 via `nvm`) without needing shell hooks or manual environment switches.
- **🎨 Native Lualine Component**: Drop-in statusline helper with dynamic colors linked to `DiagnosticOk`, `DiagnosticError`, `DiagnosticWarn`, and `DiagnosticInfo`.
- **⌨️ Interactive Control**: `:ExpoReload` command to trigger instant Metro reload (`r`) anytime without focusing the terminal window.

---

## 📦 Requirements

- Neovim `>= 0.10`
- [stevearc/overseer.nvim](https://github.com/stevearc/overseer.nvim)
- [nvim-lualine/lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) *(optional, but recommended)*

---

## 🚀 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) / [LazyVim](https://lazyvim.org)

```lua
return {
  {
    "dytra/expo-status.nvim",
    dependencies = {
      "stevearc/overseer.nvim",
      "nvim-lualine/lualine.nvim",
    },
    opts = {
      node_version = "22", -- or false to use system node
      auto_reload_on_save = true,
    },
    keys = {
      { "<leader>or", "<cmd>ExpoReload<cr>", desc = "Expo: reload Metro" },
    },
  },

  -- Add to Lualine
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}

      table.insert(opts.sections.lualine_x, 1, require("expo-status").lualine())
    end,
  },
}
```

---

## ⚙️ Configuration

Pass options to `setup()` (or via `opts = { ... }` in lazy.nvim):

```lua
require("expo-status").setup({
  -- Node.js version to select via NVM (e.g. "22", "lts/*", or false to skip nvm)
  node_version = "22",

  -- Path to NVM directory (defaults to $NVM_DIR or $HOME/.nvm)
  nvm_dir = nil,

  -- Package manager to use: "auto" | "npm" | "pnpm" | "yarn" | "bun"
  -- "auto" inspects lockfiles (pnpm-lock.yaml, yarn.lock, bun.lockb, package-lock.json)
  package_manager = "auto",

  -- Script name in package.json to run (e.g. "start" -> npm run start)
  start_script = "start",

  -- Automatically send 'r' (reload) to Metro when saving a file during error state
  auto_reload_on_save = true,

  -- Register the user command :ExpoReload
  enable_user_command = true,

  -- Status icons
  icons = {
    starting = "󰑮 ",
    running = "● ",
    ok = " ",
    error = " ",
  },

  -- Diagnostic highlight groups for statusline
  colors = {
    starting = "DiagnosticWarn",
    running = "DiagnosticInfo",
    ok = "DiagnosticOk",
    error = "DiagnosticError",
  },
})
```

---

## 🛠️ Usage

### 1. Starting Expo
1. Open your Expo project in Neovim:
   ```bash
   cd my-expo-project
   nvim .
   ```
2. Open the Overseer task runner:
   ```text
   <leader>oo  (or :OverseerRun)
   ```
3. Select **`Expo: start`** (or `Expo: start (apps/expo)` in monorepos).
4. Watch the statusline transition from `󰑮 EXPO` to `● EXPO` or ` EXPO`.

### 2. Live Error Recovery
1. Introduce an intentional syntax or module error in your React Native code.
2. The indicator turns red: ` EXPO`.
3. Fix the code and save (`:w`).
4. The plugin immediately changes the state to `󰑮 EXPO` and sends `r` to Metro.
5. As soon as Metro re-bundles successfully, it turns green: ` EXPO`.

### 3. Manual Reload
Trigger a manual Metro reload anytime with:
```vim
:ExpoReload
```
Or bind it to a keymap:
```lua
vim.keymap.set("n", "<leader>or", "<cmd>ExpoReload<cr>", { desc = "Expo: reload Metro" })
```

---

## 🎨 Custom Statusline Integration

If you use a custom statusline (Heirline, Mini.statusline, or native):

`expo-status.nvim` exposes the current state globally via:

```lua
vim.g.expo_runtime_status -- "starting" | "running" | "ok" | "error" | nil
```

And via Lua API:

```lua
local expo = require("expo-status")
local current_status = expo.get_status()
```

---

## 📄 License

[MIT](LICENSE) © 2026 [dytra](https://github.com/dytra)
