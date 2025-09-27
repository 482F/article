---
title: "[Lua] Neovim の `*` でカーソルの移動を抑制する"
emoji: "🗒"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["nixos", "wsl2"]
published: false
---

```lua
local neovim_visual_search_default = vim.tbl_filter(function(keymap)
  return keymap.lhs == '*'
end, vim.api.nvim_get_keymap('x'))[1]
for _, e in pairs({
  {
    mode = 'n',
    search = function()
      vim.api.nvim_feedkeys('*', 'nx', false)
    end,
  },
  {
    mode = 'x',
    search = function()
      neovim_visual_search_default.callback()
      vim.api.nvim_feedkeys(vim.keycode('<Esc>n'), 'nx', false)
    end,
  },
}) do
  local mode = e.mode
  local search = e.search
  vim.keymap.set(mode, '*', function()
    local view = vim.fn.winsaveview()
    pcall(search)
    vim.fn.winrestview(view)
  end)
end
```
