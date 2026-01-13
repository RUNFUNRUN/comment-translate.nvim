local config = require("comment-translate.config")
local has_plenary, curl = pcall(require, "plenary.curl")

local M = {}

local cache = {}

---@param text string
---@return string
local function hash_text(text)
  return vim.fn.sha256(text)
end

---@param text string
---@param callback fun(translated_text: string|nil, error: string|nil)
function M.translate(text, callback)
  if not text or text == "" then
    callback(nil, "Empty text")
    return
  end

  local key = hash_text(text)

  if cache[key] then
    callback(cache[key], nil)
    return
  end

  local opts = config.options

  if opts.backend == "deepl" then
    M.translate_deepl(text, function(result, err)
      if result then
        cache[key] = result
      end
      callback(result, err)
    end)
  else
    callback(nil, "Backend not implemented: " .. opts.backend)
  end
end

---@param text string
---@param callback fun(result: string|nil, error: string|nil)
function M.translate_deepl(text, callback)
  if not has_plenary then
    callback(nil, "plenary.nvim is required for API calls")
    return
  end

  local api_key = config.options.client.deepl.api_key
  if not api_key or api_key == "" then
    callback(nil, "DeepL API Key is missing")
    return
  end

  local url = config.options.client.deepl.is_pro
      and "https://api.deepl.com/v2/translate"
    or "https://api-free.deepl.com/v2/translate"

  curl.post(url, {
    body = {
      auth_key = api_key,
      text = text,
      target_lang = config.options.api.lang or "JA",
    },
    callback = vim.schedule_wrap(function(response)
      if response.status ~= 200 then
        callback(
          nil,
          "DeepL Error: "
            .. tostring(response.status)
            .. " "
            .. (response.body or "")
        )
        return
      end

      local ok, decoded = pcall(vim.json.decode, response.body)
      if not ok then
        callback(nil, "JSON Decode Error")
        return
      end

      if decoded and decoded.translations and decoded.translations[1] then
        callback(decoded.translations[1].text, nil)
      else
        callback(nil, "No translation found in response")
      end
    end),
  })
end

return M
