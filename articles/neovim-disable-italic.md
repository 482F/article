---
title: "[Lua] Neovim で斜体を無効化する"
emoji: "🗒"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Neovim", "Lua"]
published: true
published_at: 2025-10-13 00:00
---

## はじめに

斜体が苦手なので無効化します (terminal のものは対象外です)

## 実装

全ての highlight に `{ italic = false, cterm = { italic = false } }` を適用するだけです。同様にして `bold` や `underline` なども無効化できます

```lua
vim.api.nvim_create_autocmd({ 'ColorScheme' }, {
  callback = function()
    vim.fn.foreach(vim.api.nvim_get_hl(0, {}), function(hlname, def)
      local is_italic = def.italic or def.cterm and def.cterm.italic
      if not is_italic then
        return
      end

      local disabled_def = vim.tbl_deep_extend('force', def, { italic = false, cterm = { italic = false } })
      vim.api.nvim_set_hl(0, hlname, disabled_def)
    end)
  end,
})
```
