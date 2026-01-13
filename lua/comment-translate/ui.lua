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

  -- Helper to wrap text
  local function wrap(text, limit)
    limit = limit or 80
    local ret = {}
    while #text > limit do
      local chunk = vim.fn.strcharpart(text, 0, limit)
      table.insert(ret, chunk)
      text = vim.fn.strcharpart(text, limit)
    end
    table.insert(ret, text)
    return ret
  end

  if opts.position == "below" then
    local virt_lines = {}
    -- Calculate indentation (spaces equal to start_col)
    local padding = string.rep(" ", range.start_col)

    -- Calculate max width based on window width
    local max_w = opts.max_width or 80
    if winid and vim.api.nvim_win_is_valid(winid) then
      local win_width = vim.api.nvim_win_get_width(winid)
      -- Available space = Window Width - Indentation - Gutter (approx 6)
      local available = win_width - range.start_col - 6
      if available < 20 then
        available = 20
      end -- Minimum width safety
      max_w = available
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
