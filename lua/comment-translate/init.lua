local config = require("comment-translate.config")
local scanner = require("comment-translate.scanner")
local api = require("comment-translate.api")
local ui = require("comment-translate.ui")

local M = {}

---@diagnostic disable-next-line: undefined-field
local timer = (vim.uv or vim.loop).new_timer()

---@param opts? CommentTranslate.Config
function M.setup(opts)
  config.setup(opts)

  vim.api.nvim_create_user_command("CommentTranslateToggle", function()
    M.toggle()
  end, {})

  local group =
    vim.api.nvim_create_augroup("CommentTranslate", { clear = true })
  local last_comment_id = nil

  vim.api.nvim_create_autocmd({ "WinScrolled", "WinResized" }, {
    group = group,
    callback = function()
      M.update_visible()
      last_comment_id =
        scanner.get_comment_id_at_cursor(vim.api.nvim_get_current_buf())
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved" }, {
    group = group,
    callback = function()
      local current_id =
        scanner.get_comment_id_at_cursor(vim.api.nvim_get_current_buf())
      if current_id ~= last_comment_id then
        M.update_visible()
        last_comment_id = current_id
      end
    end,
  })

  M._enabled = config.options.enabled
  if M._enabled then
    M.update_visible()
  end
end

function M.is_enabled()
  return M._enabled or false
end

function M.toggle()
  if M._enabled then
    M._enabled = false
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      ui.clear(buf)
    end
  else
    M._enabled = true
    M.update_visible()
  end
end

function M.update_visible()
  if not M._enabled or not timer then
    return
  end

  timer:stop()
  timer:start(
    config.options.api.debounce_ms,
    0,
    vim.schedule_wrap(function()
      local bufnr = vim.api.nvim_get_current_buf()

      if
        vim.tbl_contains(
          config.options.exclude_filetypes,
          vim.bo[bufnr].filetype
        )
      then
        return
      end

      local winid = vim.api.nvim_get_current_win()
      local info = vim.fn.getwininfo(winid)[1]
      local comments =
        scanner.scan_comments(bufnr, info.topline - 1, info.botline)

      for _, comment in ipairs(comments) do
        local text = table.concat(comment.lines, "\n")
        text = text:gsub("^%s*[-/#]+%s*", ""):gsub("\n%s*[-/#]+%s*", "\n")

        api.translate(text, function(translation, err)
          if not err and translation then
            ui.render(bufnr, comment, translation, winid)
          end
        end)
      end
    end)
  )
end

return M
