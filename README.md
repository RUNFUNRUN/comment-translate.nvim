# comment-translate.nvim

A Neovim plugin to automatically translate comments in your code using DeepL.

## Features
- **Auto-translation**: Translates comments in the visible buffer area.
- **Lazy Loading**: Only translates what you see to save API usage.
- **Virtual Text**: Displays translations unobtrusively below the code.
- **DeepL Integration**: Uses DeepL API (Free or Pro) for high-quality translations.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "runfunrun/comment-translate.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    client = {
      deepl = {
        api_key = os.getenv("DEEPL_API_KEY"),
      }
    }
  }
}
```

### Advanced Usage (with Snacks.nvim)

```lua
{
  "runfunrun/comment-translate.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "folke/snacks.nvim" },
  init = function()
    require("comment-translate").setup({
      enabled = false,
      client = {
        deepl = {
          api_key = os.getenv("DEEPL_API_KEY"),
        },
      },
    })

    Snacks.toggle({
      name = "Comment Translate",
      get = function()
        return require("comment-translate").is_enabled()
      end,
      set = function()
        require("comment-translate").toggle()
      end,
    }):map("<leader>ut")
  end,
}
```

### Configuration
Default configuration:

```lua
require("comment-translate").setup({
  enabled = true, -- Set to false to disable on startup
  client = {
    deepl = {
      is_pro = false, -- Set to true if using DeepL Pro
    },
  },
  ui = {
    position = 'below', -- 'below', 'eol', 'overlay'
  },
  api = {
    debounce_ms = 500,
    lang = "JA",
  },
})
```

## Commands
- `:CommentTranslateToggle`: Enable/Disable the plugin globally.

## Requirements
- `nvim-lua/plenary.nvim`
- Neovim >= 0.9.0
- `curl`
