vim.api.nvim_create_user_command("PresentationStart", function()
  require("present").start_presentation()
end, {})
