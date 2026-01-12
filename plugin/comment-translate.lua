if vim.g.loaded_comment_translate == 1 then
  return
end
vim.g.loaded_comment_translate = 1

-- Expose global setup if desired, or rely on require('comment-translate').setup
-- Standard convention is usually requiring the lua module.
