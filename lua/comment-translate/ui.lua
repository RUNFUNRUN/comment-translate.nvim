local config = require("comment-translate.config")
local NAMESPACE = vim.api.nvim_create_namespace("CommentTranslate")

local M = {}

---@param bufnr integer
function M.clear(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, NAMESPACE, 0, -1)
  end
end

---@param text string
---@param limit integer
---@return string[]
local function wrap_text(text, limit)
  local ret = {}

  while vim.fn.strdisplaywidth(text) > limit do
    local char_count = vim.fn.strchars(text)
    local cut_pos = 1

    for i = 1, char_count do
      local width = vim.fn.strdisplaywidth(vim.fn.strcharpart(text, 0, i))
      if width > limit then
        break
      end
      cut_pos = i
    end

    table.insert(ret, vim.fn.strcharpart(text, 0, cut_pos))
    text = vim.fn.strcharpart(text, cut_pos)
  end

  if vim.fn.strchars(text) > 0 then
    table.insert(ret, text)
  end
  return ret
end

---@param winid? integer
---@return integer
local function get_effective_winid(winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    return winid
  end
  return vim.api.nvim_get_current_win()
end

---@param bufnr integer
---@param range CommentRange
---@param translation string
---@param winid? integer
function M.render(bufnr, range, translation, winid)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local opts = config.options.ui
  local lines = vim.split(translation, "\n")

  if opts.position == "below" then
    local virt_lines = {}
    local padding = string.rep(" ", range.start_col)

    local effective_winid = get_effective_winid(winid)
    local wininfo = vim.fn.getwininfo(effective_winid)[1]
    local text_width = wininfo.width - wininfo.textoff
    local prefix_width = 2 -- "↳ " or "  "
    local max_w = math.max(text_width - range.start_col - prefix_width - 1, 20)

    if opts.max_width then
      max_w = math.min(max_w, opts.max_width)
    end

    for _, line in ipairs(lines) do
      local wrapped = wrap_text(line, max_w)
      for i, w_line in ipairs(wrapped) do
        local prefix = (i == 1) and "↳ " or "  "
        table.insert(virt_lines, { { padding .. prefix .. w_line, "Comment" } })
      end
    end

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
