local config = require("comment-translate.config")
local NAMESPACE = vim.api.nvim_create_namespace("CommentTranslate")

local M = {}

---@param bufnr integer
function M.clear(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, NAMESPACE, 0, -1)
  end
end

---Render translation for a range
---@param bufnr integer
---@param range CommentRange
---@param translation string
---@param winid? integer
function M.render(bufnr, range, translation, winid)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local opts = config.options.ui

  -- Split translation into lines if it's long or contains newlines
  local lines = vim.split(translation, "\n")

  -- Helper to wrap text (supports multibyte/fullwidth characters using display width)
  local function wrap(text, limit)
    local ret = {}

    while vim.fn.strdisplaywidth(text) > limit do
      -- Find the character position where display width exceeds limit
      local char_count = vim.fn.strchars(text)
      local cut_pos = 0

      for i = 1, char_count do
        local substr = vim.fn.strcharpart(text, 0, i)
        if vim.fn.strdisplaywidth(substr) > limit then
          cut_pos = i - 1
          break
        end
        cut_pos = i
      end

      if cut_pos == 0 then
        cut_pos = 1 -- At least one character
      end

      local chunk = vim.fn.strcharpart(text, 0, cut_pos)
      table.insert(ret, chunk)
      text = vim.fn.strcharpart(text, cut_pos)
    end

    if vim.fn.strchars(text) > 0 then
      table.insert(ret, text)
    end
    return ret
  end

  if opts.position == "below" then
    local virt_lines = {}
    -- Calculate indentation (spaces equal to start_col)
    local padding = string.rep(" ", range.start_col)

    -- Calculate max width based on window width
    local effective_winid = winid
    if not effective_winid or not vim.api.nvim_win_is_valid(effective_winid) then
      effective_winid = vim.api.nvim_get_current_win()
    end
    local win_width = vim.api.nvim_win_get_width(effective_winid)
    -- Available space = Window Width - Indentation - Gutter - prefix - margin
    local max_w = win_width - range.start_col - 10
    if max_w < 20 then
      max_w = 20
    end -- Minimum width safety

    -- Apply max_width limit only if explicitly configured
    if opts.max_width then
      max_w = math.min(max_w, opts.max_width)
    end

    for _, line in ipairs(lines) do
      local wrapped = wrap(line, max_w)
      for i, w_line in ipairs(wrapped) do
        -- First line has arrow, others just indented
        local prefix = (i == 1) and "↳ " or "  "
        table.insert(virt_lines, { { padding .. prefix .. w_line, "Comment" } })
      end
    end

    -- Clear existing mark on this line to avoid stacking
    vim.api.nvim_buf_clear_namespace(
      bufnr,
      NAMESPACE,
      range.end_row,
      range.end_row + 1
    )

    vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, range.end_row, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
    })
  elseif opts.position == "eol" then
    -- Only render valid first line to avoid mess
    local text = lines[1] or ""
    if #lines > 1 then
      text = text .. "..."
    end

    vim.api.nvim_buf_clear_namespace(
      bufnr,
      NAMESPACE,
      range.start_row,
      range.start_row + 1
    )

    vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, range.start_row, 0, {
      virt_text = { { "  " .. text, "Comment" } },
      virt_text_pos = "eol",
    })
  elseif opts.position == "overlay" then
    vim.api.nvim_buf_clear_namespace(
      bufnr,
      NAMESPACE,
      range.start_row,
      range.end_row + 1
    )

    vim.api.nvim_buf_set_extmark(
      bufnr,
      NAMESPACE,
      range.start_row,
      range.start_col,
      {
        end_row = range.end_row,
        end_col = range.end_col,
        virt_text = { { translation, "Comment" } },
        virt_text_pos = "overlay",
      }
    )
  end
end

return M
