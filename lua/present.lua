local M = {}

local function create_floating_window(config, enter)
  if enter == nil then
    enter = false
  end

  -- Create a buffer for the floating window
  --
  local buf = vim.api.nvim_create_buf(false, true) -- false: not listed, true: scratch buffer

  -- Create the floating window
  local win = vim.api.nvim_open_win(buf, enter or false, config)

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
  end
  table.insert(slides.slides, current_slide) -- Add the last slide

  return slides
end

local create_window_config = function()
  local width = vim.o.columns
  local height = vim.o.lines

  local header_height = 1 + 2 -- 1 + border
  local footer_height = 1 -- 1, no border

  local body_height = height - header_height - footer_height - 2 - 1 -- for body border

  return {
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
      height = body_height,
      row = 4,
      col = 8,
      style = "minimal",
      border = { " ", " ", " ", " ", " ", " ", " ", " " },
      zindex = 2,
    },
    footer = {
      relative = "editor",
      width = width,
      height = 1,
      row = height - 1,
      col = 1,
      style = "minimal",
      zindex = 2,
    },
  }
end

local state = {
  parsed = {},
  current_slide = 1,
  floats = {},
  title = "",
}

local foreach_float = function(callback)
  for name, float in pairs(state.floats) do
    callback(name, float)
  end
end

local present_keymap = function(mode, key, cb)
  vim.keymap.set(mode, key, cb, { buffer = state.floats.body.buf })
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0

  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  state.parsed_slides = parse_slides(lines)
  state.current_slide = 1
  state.title = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.bufnr), ":t")

  local windows = create_window_config()
  state.floats.background = create_floating_window(windows.background)
  state.floats.header = create_floating_window(windows.header)
  state.floats.footer = create_floating_window(windows.footer)
  state.floats.body = create_floating_window(windows.body, true)

  foreach_float(function(_, float)
    vim.bo[float.buf].filetype = "markdown"
  end)

  local set_slide_content = function(idx)
    local slide = state.parsed_slides.slides[idx]

    local title = slide.title
    local padding = string.rep(" ", math.floor((vim.o.columns - #title) / 2))
    vim.api.nvim_buf_set_lines(state.floats.header.buf, 0, -1, false, { padding .. title })
    vim.api.nvim_buf_set_lines(state.floats.footer.buf, 0, -1, false, {
      string.format("Slide %d/%d | %s", idx, #state.parsed_slides.slides, state.title),
    })
    vim.api.nvim_buf_set_lines(state.floats.body.buf, 0, -1, false, slide.body)
  end

  present_keymap("n", "n", function()
    state.current_slide = math.min(state.current_slide + 1, #state.parsed_slides.slides)
    set_slide_content(state.current_slide)
  end)

  present_keymap("n", "p", function()
    state.current_slide = math.max(state.current_slide - 1, 1)
    set_slide_content(state.current_slide)
  end)

  present_keymap("n", "q", function()
    vim.api.nvim_win_close(state.floats.body.win, true)
  end)

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
    buffer = state.floats.body.buf,
    callback = function()
      -- Restore original options when leaving the presentation
      for option, config in pairs(restore) do
        vim.opt[option] = config.original
      end

      foreach_float(function(_, float)
        pcall(vim.api.nvim_buf_delete, float.buf, { force = true })
      end)
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("PresentationResize", { clear = true }),
    callback = function()
      if not vim.api.nvim_win_is_valid(state.floats.body.win) or state.floats.body.win == nil then
        return
      end

      local new_windows = create_window_config()
      foreach_float(function(name, _)
        vim.api.nvim_win_set_config(state.floats[name].win, new_windows[name])
      end)

      -- Recalculate slide content
      set_slide_content(state.current_slide)
    end,
  })

  set_slide_content(state.current_slide) -- Set the initial slide content
end

-- M.start_presentation { bufnr = 9 }

-- vim.print(parse_slides {
--   "# Hello",
--   "this is somethine else",
--   "# World",
--   "this is the second slide",
-- })

return M
