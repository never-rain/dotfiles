return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      local image = vim.fn.expand("~/.config/wallpapers/16.png")

      opts.dashboard.sections = {
        {
          section = "terminal",
          cmd = "chafa "
            .. vim.fn.shellescape(image)
            .. " --format symbols --symbols vhalf --size 60x17 --stretch; sleep 0.1",
          height = 17,
          padding = 1,
        },
        {
          --pane = 2,
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      }
    end,
  },
}
