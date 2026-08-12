return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "biome",
        "css-lsp",
        "html-lsp",
        "json-lsp",
        "vtsls",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        html = {},
        cssls = {},
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        html = { "biome-check" },
      },
    },
  },
}
