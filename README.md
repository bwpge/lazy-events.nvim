# lazy-events.nvim

A Neovim plugin for simplifying custom event logic with [`lazy.nvim`](https://github.com/folke/lazy.nvim).

## Overview

The `lazy.nvim` plugin manager has a quite clever event system for lazy loading plugins. However, it is a bit tedious to hook custom event logic into the event mappings without some deliberate boilerplate, and it needs to be done before plugin specs are loaded. This plugin seeks to make that process easier.

This plugin provides a simple interface for creating three styles of events, and adding them to `lazy.nvim` event mappings:

- **simple**: a "wrapper" for any number of other events (e.g., `LazyFile` used by [LazyVim](https://www.lazyvim.org/) is a wrapper for `BufReadPost`, `BufNewFile`, and `BufWritePre`)
- **projects**: detecting a certain structure of files or directories in the current working directory (for example, Rust projects typically contain `Cargo.toml` in the project root)
- **custom**: arbitrary logic determining if the event should be fired, executed on any matching event

See the [Examples](#examples) section for more information.

### Why?

There are existing solutions available for lazy loading logic, such as by commands, keys, or filetypes. These should be preferred when possible.

However, sometimes this is not sufficient. It might be preferable to lazy load heavy plugins in only certain projects or when certain things happen. For example:

- [CMake | LazyVim - cmake-tools.nvim](https://www.lazyvim.org/extras/lang/cmake#cmake-toolsnvim): `init` checks if `CMakeLists.txt` exists before loading
- [Editor | LazyVim - neo-tree.nvim](https://www.lazyvim.org/plugins/editor#neo-treenvim): `init` checks if Neovim was started with a directory as first argument

## Installation

Installation is a bit different than other plugins, since this plugin has to execute some logic before other plugin specs are loaded. In whatever module you run `require("lazy").setup(...)`, you must add this plugin as the first spec in your config.

You might have one of the following common setups:

```lua
-- no plugin module, like kickstart.nvim
require("lazy").setup({
    "tpope/vim-sleuth",
    { "numToStr/Comment.nvim", opts = {} },
    -- ...
}, {
    -- lazy.nvim options
})

-- single plugin module
require("lazy").setup("user.plugins", {
    -- lazy.nvim options
})

-- multiple plugin modules
require("lazy").setup({
    { import = "user.plugins" },
    { import = "user.plugins.lsp" },
}, {
    -- lazy.nvim options
})

-- LazyVim starter
require("lazy").setup({
    spec = {
        { "LazyVim/LazyVim", import = "lazyvim.plugins" },
        { import = "lazyvim.plugins.extras.lang.typescript" },
        -- ...
        { import = "plugins" },
    },
}, {
    -- lazy.nvim options
})
```

You will need to make this plugin the first spec:

```diff
 -- no plugin module, like kickstart.nvim
 require("lazy").setup({
-    "tpope/vim-sleuth",
-    { "numToStr/Comment.nvim", opts = {} },
-    -- ...
+    { "bwpge/lazy-events.nvim", import = "lazy-events.plugins", lazy = false },
+    {
+        "tpope/vim-sleuth",
+        { "numToStr/Comment.nvim", opts = {} },
+        -- ...
+    },
 }, {
        -- lazy.nvim options
 })

 -- single plugin module
-require("lazy").setup("user.plugins", {
+require("lazy").setup({
+    { "bwpge/lazy-events.nvim", import = "lazy-events.plugins", lazy = false },
+    { import = "user.plugins" },
+}, {
        -- lazy.nvim options
 })

 -- multiple plugin modules
 require("lazy").setup({
+    { "bwpge/lazy-events.nvim", import = "lazy-events.plugins", lazy = false },
     { import = "user.plugins" },
     { import = "user.plugins.lsp" },
 }, {
     -- lazy.nvim options
 })

 -- LazyVim starter
 require("lazy").setup({
     spec = {
+        { "bwpge/lazy-events.nvim", import = "lazy-events.plugins", lazy = false },
         { "LazyVim/LazyVim", import = "lazyvim.plugins" },
         { import = "lazyvim.plugins.extras.lang.typescript" },
         -- ...
         { import = "plugins" },
     },
 }, {
     -- lazy.nvim options
 })
```

## Configuration

Configuration for this plugin is passed through `vim.g.lazy_events_config`. This is a bit odd, but there is not currently a way to pass data data to plugin specs through spec imports.

```lua
-- in setup.lua or wherever you bootstrap lazy.nvim

vim.g.lazy_events_config = {
    -- simple wrapper events, no logic
    simple = {
        TermUsed = { "TermOpen", "TermEnter", "TermLeave", "TermClose" },
    },
    -- projects use glob matches to check if event should fire (see `:h wildcards`)
    -- these events are checked on DirChanged events and fired as `LazyProject:<key>`
    projects = {
        -- shorthand for "match any"
        docker = { "Dockerfile", "compose.y*ml", "docker-compose.y*ml" },
        -- can use more explicit globs with `any` and `all` fields:
        cpplib = {
            "BUILD.bazel", "BUILD", -- gets merged with `any` table
            any = { "Makefile", "CMakeLists.txt", "Justfile" },
            all = { "**/*.cpp", "**/*.h*" }, -- all expresions must match something
        },
    },
    -- more involved event logic can be configured here
    custom = {
        -- dumb, but illustrates basic usage
        OddBufNumber = {
            event = "BufEnter", -- event(s) to listen for
            pattern = "*", -- pattern to match on event
            once = false, -- if this event should only be checked once
            -- logic to determine if `OddBufNumber` event should fire (must return `true` to fire)
            cond = function(event)
                -- `event` is from the `nvim_create_autocmd` callback function
                return event.buf % 2 == 1
            end,
        }
    }
}

require("lazy").setup({
    spec = {
        { "bwpge/lazy-events.nvim", import = "lazy-events.plugins", lazy = false },
        -- ...
    },
    -- ...
})
```

## Examples

The following are examples of each type of event that can be configured.

### Simple: LazyFile

An easy example is adding [`LazyFile` events](https://github.com/LazyVim/LazyVim/blob/4d706f1bdc687f1d4d4cd962ec166c65c453633e/lua/lazyvim/util/plugin.lua#L84-L88) (as used in LazyVim). This event allows lazy loading plugins which require an open file to be useful, such as `todo-comments`, `gitsigns`, various LSP functions, etc.

For those not using LazyVim, we can configure the same event with the following:

```lua
-- in setup.lua or wherever you bootstrap lazy.nvim

vim.g.lazy_events_config = {
    simple = {
        LazyFile = { "BufReadPost", "BufNewFile", "BufWritePre" },
    }
}

require("lazy").setup({
    spec = {
        { "bwpge/lazy-events.nvim", import = "lazy-events.plugins" },
        {
            "folke/todo-comments.nvim",
            -- load on LazyFile or given cmd
            event = "LazyFile",
            cmd = { "TodoTrouble", "TodoTelescope" },
            -- ...
        },
    },
})
```

### LazyProject: CMake

Some plugins are only useful in specific project types. Take [`cmake-tools.nvim`](https://github.com/Civitasv/cmake-tools.nvim) for example. This is a great plugin, but offers zero function outside of CMake projects. It has a fairly hefty cost to load, and installs a lot of commands, autocmds, and other hooks that we really don't need running and consuming resources if not in a CMake project. However, we might want to load automatically load this plugin when entering a CMake project.

We can create an event for detecting CMake projects:

```lua
-- in setup.lua or wherever you bootstrap lazy.nvim

vim.g.lazy_events_opts = {
    projects = {
        -- triggers `LazyProject:cmake` if glob matches
        cmake = { "CMakeLists.txt" }
        -- equivalent to:
        --   cmake = { any = { "CMakeLists.txt" } }
    }
}

require("lazy").setup({
    spec = {
        { "bwpge/lazy-events.nvim", import = "lazy-events.plugins" },
        -- ...
    },
})
```

We can then use that in the `cmake-tools` plugin spec:

```lua
-- in plugins/cmake-tools.lua or wherever the plugin spec is defined:

return {
    "Civitasv/cmake-tools.nvim",
    -- use `LazyProject:<type>` event, no complicated `init` function required
    event = "LazyProject:cmake",
    config = function(_, opts)
        require("cmake-tools").setup(opts or {})

        -- since this is only ever loaded in a cmake project, we are safe to
        -- execute some more logic here like setting targets, kits, generating,
        -- building, etc.
    end,
}
```

### Custom: StartWithDir

Let's use LazyVim again for an example: [Editor | LazyVim - neo-tree.nvim](https://www.lazyvim.org/plugins/editor#neo-treenvim). If you view the full spec, the [`init` function](https://github.com/LazyVim/LazyVim/blob/4d706f1bdc687f1d4d4cd962ec166c65c453633e/lua/lazyvim/plugins/editor.lua#L46-L64) looks complicated, but is just checking to see if Neovim was started with a directory as the first argument.

We can create a custom `StartWithDir` event:

```lua
-- in setup.lua or wherever you bootstrap lazy.nvim

vim.g.lazy_events_config = {
    custom = {
        StartWithDir = {
            event = "BufEnter",
            once = true,
            -- cond must return `true` to fire `StartWithDir`
            cond = function()
                local arg = vim.fn.argv(0)
                if arg == "" then
                    return false
                end

                local stats = vim.uv.fs_stat(arg)
                return (stats and stats.type == "directory") or false
            end,
        },
    },
}
```

Then use it in the `neo-tree.nvim` plugin spec:

```lua
-- in plugins/neo-tree.lua or wherever the plugin spec is defined:

return {
    "nvim-neo-tree/neo-tree.nvim",
    event = "StartWithDir",
    -- ...
}
```
