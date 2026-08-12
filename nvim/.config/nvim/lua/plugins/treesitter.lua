return {
  {
    "nvim-treesitter/nvim-treesitter",
    init = function()
      -- A fresh install can reach this from the plugin build and config paths at the same time.
      LazyVim.treesitter.ensure_treesitter_cli = function(callback)
        if vim.fn.executable("tree-sitter") == 1 then
          return callback(true)
        end

        if not pcall(require, "mason") then
          return callback(false, "`mason.nvim` is disabled, so `tree-sitter-cli` cannot be installed automatically.")
        end

        if vim.fn.executable("tree-sitter") == 1 then
          return callback(true)
        end

        local registry = require("mason-registry")
        registry.refresh(function()
          local package = registry.get_package("tree-sitter-cli")
          local error_message = "Failed to install `tree-sitter-cli` with `mason.nvim`."
          local finished = false
          local on_success
          local on_failure

          local function complete(success)
            if finished then
              return
            end
            finished = true
            if on_success then
              package:off("install:success", on_success)
              package:off("install:failed", on_failure)
            end
            vim.schedule(function()
              callback(success, success and nil or error_message)
            end)
          end

          if package:is_installed() then
            return complete(true)
          end

          if package:is_installing() then
            on_success = function()
              complete(true)
            end
            on_failure = function()
              complete(false)
            end
            package:once("install:success", on_success)
            package:once("install:failed", on_failure)
            return
          end

          LazyVim.info("Installing `tree-sitter-cli` with `mason.nvim`...")
          package:install(nil, function(success)
            if success then
              LazyVim.info("Installed `tree-sitter-cli` with `mason.nvim`.")
            end
            complete(success)
          end)
        end)
      end
    end,
  },
}
