local M = {}

---@class CommentRange
---@field start_row integer
---@field end_row integer
---@field start_col integer
---@field end_col integer
---@field lines string[]
---@field id string -- Unique hash for caching

---Extract comment text from a Tree-sitter node
---@param node TSNode
---@param bufnr integer
---@return string[]
local function get_node_text(node, bufnr)
  local start_row, start_col, end_row, end_col = node:range()

  -- Safety check for valid buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end

  if end_row >= start_row then
    local lines =
      vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
    if #lines > 0 then
      if #lines == 1 then
        lines[1] = string.sub(lines[1], start_col + 1, end_col)
      else
        lines[1] = string.sub(lines[1], start_col + 1)
        lines[#lines] = string.sub(lines[#lines], 1, end_col)
      end
    end
    return lines
  end
  return {}
end

---Scan buffer for comments in the given range
---@param bufnr integer
---@param start_row? integer 0-indexed, inclusive
---@param end_row? integer 0-indexed, exclusive
---@return CommentRange[]
function M.scan_comments(bufnr, start_row, end_row)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end

  -- Defaults to whole buffer if not specified
  start_row = start_row or 0
  end_row = end_row or vim.api.nvim_buf_line_count(bufnr)

  local ft = vim.bo[bufnr].filetype
  local lang = vim.treesitter.language.get_lang(ft) or ft

  -- Check if parser is available
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then
    return {}
  end

  local tree = parser:parse()[1]
  if not tree then
    return {}
  end

  local root = tree:root()
  -- "highlights" query usually contains @comment
  local query = vim.treesitter.query.get(lang, "highlights")
  if not query then
    return {}
  end

  local comments = {}

  for id, node, _ in query:iter_captures(root, bufnr, start_row, end_row) do
    local capture_name = query.captures[id]

    if capture_name == "comment" then
      local s_row, s_col, e_row, e_col = node:range()

      -- Strict overlap check can be added if needed, iter_captures handles the broad range
      -- We want to ensure we don't duplicate or miss

      local lines = get_node_text(node, bufnr)

      if #lines > 0 then
        table.insert(comments, {
          start_row = s_row,
          end_row = e_row,
          start_col = s_col,
          end_col = e_col,
          lines = lines,
          -- Create a simplified ID based on position.
          -- Content hash would be better for translation caching, but position is good for UI tracking.
          id = string.format("%d:%d-%d:%d", s_row, s_col, e_row, e_col),
        })
      end
    end
  end

  -- Merge consecutive comments
  return M.merge_consecutive_comments(comments)
end

---Merge consecutive single-line comments into a single CommentRange
---Comments are considered consecutive if:
---  1. Their row numbers are adjacent (end_row + 1 == next start_row)
---  2. They have the same indentation (start_col)
---@param comments CommentRange[]
---@return CommentRange[]
function M.merge_consecutive_comments(comments)
  if #comments <= 1 then
    return comments
  end

  -- Sort by start_row to ensure proper ordering
  table.sort(comments, function(a, b)
    return a.start_row < b.start_row
  end)

  ---Check if a comment is empty (only comment markers and whitespace)
  ---@param comment CommentRange
  ---@return boolean
  local function is_empty_comment(comment)
    for _, line in ipairs(comment.lines) do
      -- Remove common comment prefixes and whitespace
      local content = line:gsub("^%s*[-/#*]+%s*", "")
      if content ~= "" then
        return false
      end
    end
    return true
  end

  local merged = {}
  local current = comments[1]

  -- Skip if current is empty
  if is_empty_comment(current) then
    current = nil
  end

  for i = 2, #comments do
    local next_comment = comments[i]

    -- Skip empty comments (they act as separators)
    if is_empty_comment(next_comment) then
      if current then
        table.insert(merged, current)
        current = nil
      end
      goto continue
    end

    if current == nil then
      current = next_comment
      goto continue
    end

    -- Check if comments are consecutive and have same indentation
    local is_consecutive = (current.end_row + 1 == next_comment.start_row)
    local same_indent = (current.start_col == next_comment.start_col)

    if is_consecutive and same_indent then
      -- Merge: extend current comment to include next
      for _, line in ipairs(next_comment.lines) do
        table.insert(current.lines, line)
      end
      current.end_row = next_comment.end_row
      current.end_col = next_comment.end_col
      -- Update ID to reflect merged range
      current.id = string.format(
        "%d:%d-%d:%d",
        current.start_row,
        current.start_col,
        current.end_row,
        current.end_col
      )
    else
      -- Not consecutive, save current and start new group
      table.insert(merged, current)
      current = next_comment
    end

    ::continue::
  end

  -- Don't forget the last group
  if current then
    table.insert(merged, current)
  end

  return merged
end

---Check if cursor is currently inside a comment
---@param bufnr integer
---@return string|nil id Unique ID of the comment node if inside, else nil
function M.get_comment_id_at_cursor(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]

  -- Re-use scan but optimized? Or just simple query.
  -- Ideally we query just the point.
  local scan_res = M.scan_comments(bufnr, row, row + 1)
  for _, c in ipairs(scan_res) do
    if row >= c.start_row and row <= c.end_row then
      if c.start_row == c.end_row then
        if col >= c.start_col and col < c.end_col then
          return c.id
        end
      else
        local in_range = true
        if row == c.start_row and col < c.start_col then
          in_range = false
        end
        if row == c.end_row and col >= c.end_col then
          in_range = false
        end
        if in_range then
          return c.id
        end
      end
    end
  end
  return nil
end

return M
