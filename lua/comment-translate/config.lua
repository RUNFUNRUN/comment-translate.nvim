---@class CommentTranslate.Config
local default_config = {
	---@type boolean
	enabled = true,
	---@type 'deepl' | 'google' | 'custom'
	backend = "deepl",
	client = {
		deepl = {
			api_key = os.getenv("DEEPL_API_KEY") or "",
			is_pro = false, -- Set to true if using DeepL Pro
		},
	},
	ui = {
		---@type 'eol' | 'below' | 'overlay'
		position = "below",
		max_width = 80,
	},
	api = {
		debounce_ms = 500,
		lang = "JA", -- Target language (e.g. JA, EN, FR)
	},
	---@type table<string, boolean>
	exclude_filetypes = {
		"TelescopePrompt",
		"neo-tree",
		"lazy",
	},
}

---@class CommentTranslate.ConfigModule
local M = {}

M.options = vim.deepcopy(default_config)

---@param opts? CommentTranslate.Config
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", default_config, opts or {})
end

return M
