local M = {}

local function create_floating_window(config)
  -- Create a buffer for the floating window
  local buf = vim.api.nvim_create_buf(false, true) -- false: not listed, true: scratch buffer

  -- Create the floating window
  local win = vim.api.nvim_open_win(buf, true, config)

  return { buf = buf, win = win }
end

--- @class present.Slides
--- @field slides present.Slide[]: the slides in the presentation

--- @class present.Slide
--- @field title string: the title of the slide
--- @field body string[]: the body of the slide

--- Takes some lines and parses them
--- @param lines string[]: lines in the buffer
--- @return present.Slides
local parse_slides = function(lines)
  local slides = { slides = {} }
  local current_slide = {
    title = "",
    body = {},
  }

  local separator = "^#"

  for _, line in ipairs(lines) do
    if line:find(separator) then
      -- If we have a current slide, save it before starting a new one
      if #current_slide.title > 0 then
        table.insert(slides.slides, current_slide)
      end

      current_slide = {
        title = line,
        body = {},
      }
    else
      table.insert(current_slide.body, line)
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

  local width = vim.o.columns
  local height = vim.o.lines
  --- @type vim.api.keyset.win_config[]
  local windows = {
    background = {
      relative = "editor",
      width = width,
      height = height,
      row = 0,
      col = 0,
      style = "minimal",
      zindex = 1,
    },
    header = {
      relative = "editor",
      width = width,
      height = 1,
      row = 0,
      col = 1,
      style = "minimal",
      border = "rounded",
      zindex = 2,
    },
    body = {
      relative = "editor",
      width = width - 8,
      height = height - 5, -- Leave space for header and footer
      row = 4,
      col = 8,
      style = "minimal",
      border = { " ", " ", " ", " ", " ", " ", " ", " " },
      zindex = 2,
    },
    -- footer = {},
  }

  local background_floating_window = create_floating_window(windows.background)
  local header_floating_window = create_floating_window(windows.header)
  local body_floating_window = create_floating_window(windows.body)

  vim.bo[header_floating_window.buf].filetype = "markdown"
  vim.bo[body_floating_window.buf].filetype = "markdown"

  local set_slide_content = function(idx)
    local slide = parsed_slides.slides[idx]

    local title = slide.title
    local padding = string.rep(" ", math.floor((width - #title) / 2))
    vim.api.nvim_buf_set_lines(header_floating_window.buf, 0, -1, false, { padding .. title })
    vim.api.nvim_buf_set_lines(body_floating_window.buf, 0, -1, false, slide.body)
  end

  local slide_index = 1
  vim.keymap.set("n", "n", function()
    slide_index = math.min(slide_index + 1, #parsed_slides.slides)
    set_slide_content(slide_index)
  end, { buffer = body_floating_window.buf })

  vim.keymap.set("n", "p", function()
    slide_index = math.max(slide_index - 1, 1)
    set_slide_content(slide_index)
  end, { buffer = body_floating_window.buf })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(body_floating_window.win, true)
  end, { buffer = body_floating_window.buf })

  local restore = {
    cmdheight = {
      original = vim.o.cmdheight,
      present = 0,
    },
  }

  -- Set options for the presentation
  for option, config in pairs(restore) do
    vim.opt[option] = config.present
  end

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = body_floating_window.buf,
    callback = function()
      -- Restore original options when leaving the presentation
      for option, config in pairs(restore) do
        vim.opt[option] = config.original
      end

      pcall(vim.api.nvim_win_close, header_floating_window.win, true)
      pcall(vim.api.nvim_win_close, background_floating_window.win, true)
    end,
  })

  set_slide_content(slide_index) -- Set the initial slide content
end

-- M.start_presentation { bufnr = 14 }

-- vim.print(parse_slides {
--   "# Hello",
--   "this is somethine else",
--   "# World",
--   "this is the second slide",
-- })

return M
