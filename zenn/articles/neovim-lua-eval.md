---
title: "Neovim で選択行の Lua を実行し、結果を取得する"
emoji: "🗒"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Neovim", "Lua"]
published: false
---

## はじめに

Neovim で Lua を書いていると、しばしば一部分だけ実行したくなることがありますよね？
値に何が入っているか見たり、処理がうまく動いているか確認したり、一時的な設定の変更を適用したり・・・
簡単に選択範囲を実行できると便利なのでキーマップにしました

## 実装

下記のようにすると、Visual/Select モード時に `<leader>q` を押下することで選択した範囲の行が実行されます
:::message
下記コードでは選択範囲そのものを実行するようにはなっていません
:::
また、実行結果は `vim.inspect` して `vim.notify` に渡され、さらに nil でない場合は `vim.fn.setreg` でクリップボードに入るようになっています

```lua
vim.keymap.set('x', '<leader>q', function()
  vim.fn.feedkeys(':', 'nx') -- Visual/Select モード解除
  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  local selected = vim.api.nvim_buf_get_lines(s[1], s[2] - 1, e[2], false)
  local all_lines = vim.fn.flatten({
    '(function()',
    '  local raw_result = (function()',
    selected,
    '  end)()',
    '  local result = vim.inspect(raw_result)',
    '  vim.notify(result)',
    '  if result ~= "nil" then',
    '    vim.fn.setreg("*", result)',
    '  end',
    'end)()',
  })
  local script = vim.fn.join(all_lines, '\n')
  vim.fn.luaeval(script)
end, { desc = 'Lua スクリプト実行' })
```

## 使用例

`Normal` highlight の色を変える場合を考えます。以下のコードブロックは全て上のキーマップで実行するものとします

まず `Normal` にどんな定義が入っているかを取得します

```lua
return vim.api.nvim_get_hl(0, { name = 'Normal' })
-- {
--   bg = 14145495,
--   ctermbg = 188,
--   ctermfg = 16,
--   fg = 0
-- }
```

bg を 16 進数文字に変換します

```lua
return string.format('%x', 14145495)
-- "d7d7d7"
```

値を少し変えて、意図した色になっているかを確認します

```lua
local normal_hl = vim.api.nvim_get_hl(0, { name = 'Normal' })
normal_hl.bg = "#d7f7d7"
vim.api.nvim_set_hl(0, 'Normal', normal_hl)
```

調整に満足がいったら設定に書くなどして恒久的に適用します
