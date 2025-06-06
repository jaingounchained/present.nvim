local M = {}

local function create_floating_window(opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)

  -- Calculate the position to center the window
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create a buffer for the floating window
  local buf = vim.api.nvim_create_buf(false, true) -- false: not listed, true: scratch buffer

  -- Define window configuration
  --- @type vim.api.keyset.win_config
  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded", -- or "single", "double", "solid", "shadow"
  }

  -- Create the floating window
  local win = vim.api.nvim_open_win(buf, true, win_config)

  return { buf = buf, win = win }
end

--- @class present.Slides
--- @field slides string[]: the slides in the presentation

--- Takes some lines and parses them
--- @param lines string[]: lines in the buffer
--- @return present.Slides
local parse_slides = function(lines)
  local slides = { slides = {} }
  local current_slide = {}

  local separator = "^#"

  for _, line in ipairs(lines) do
    if line:find(separator) then
      -- If we have a current slide, save it before starting a new one
      if #current_slide > 0 then
        table.insert(slides.slides, current_slide)
      end

      current_slide = {}
    end
    -- Continue adding lines to the current slide
    table.insert(current_slide, line)
  end
  table.insert(slides.slides, current_slide) -- Add the last slide

  return slides
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0

  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  local parsed_slides = parse_slides(lines)
  local floating_window = create_floating_window()

  ---@diagnostic disable-next-line: param-type-mismatch
  vim.api.nvim_buf_set_lines(floating_window.buf, 0, -1, false, parsed_slides.slides[1])

  local slide_index = 1
  vim.keymap.set("n", "n", function()
    slide_index = math.min(slide_index + 1, #parsed_slides.slides)
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.api.nvim_buf_set_lines(floating_window.buf, 0, -1, false, parsed_slides.slides[slide_index])
  end, { buffer = floating_window.buf })

  vim.keymap.set("n", "p", function()
    slide_index = math.max(slide_index - 1, 1)
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.api.nvim_buf_set_lines(floating_window.buf, 0, -1, false, parsed_slides.slides[slide_index])
  end, { buffer = floating_window.buf })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(floating_window.win, true)
  end, { buffer = floating_window.buf })
end

-- M.start_presentation { bufnr = 63 }

-- vim.print(parse_slides {
--   "# Hello",
--   "this is somethine else",
--   "# World",
--   "this is the second slide",
-- })

return M
