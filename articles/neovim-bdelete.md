---
title: "[Lua] Neovim で良い感じの :bdelete をする"
emoji: "🗒"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Neovim", "Lua"]
published: false
---

## はじめに
`:bnext`、`:bprev` を使ってファイルを移動し、用済みのものは `:bdelete` で消す運用をしていました
ただ、既存の `:bdelete` に不満がいくつかあったので、それらを解消したものを作ります

変更点は下記の通りです
- ウィンドウが閉じることを抑制できる
- 遷移先を「直感的に直前の位置」(以後 `位置 P`) にする
    - 説明は後述します

## 実装

```lua
---@param write boolean
---@param bang boolean
---@param winclose boolean
---@param bufnr? integer
local function bd(write, bang, winclose, bufnr)
  bufnr = bufnr or vim.fn.bufnr()

  if write then
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd.write()
    end)
  end

  -- ウィンドウを閉じて良いなら既存コマンドをそのまま使う
  if winclose then
    vim.cmd.bdelete({ args = { bufnr }, bang = bang })
    return
  end

  -- 閉じる対象のバッファを開いているウィンドウ全てで処理を行える関数を定義
  local allwinids = vim.fn.win_findbuf(bufnr)
  ---@param func fun(winid: number): nil
  local function runallwin(func)
    vim.fn.foreach(allwinids, function(_, winid)
      vim.api.nvim_win_call(winid, function()
        func(winid)
      end)
    end)
  end

  -- 各ウィンドウの view を保持しておき、閉じるのに失敗したときに復元する
  local views = {}

  runallwin(function(winid)
    views[winid] = vim.fn.winsaveview()

    local winnr = vim.api.nvim_win_get_number(winid)
    local all_jumps, last_jump = unpack(vim.fn.getjumplist(winnr))

    -- 位置 P を導出する
    local sorted_jumps = vim.fn.flatten({
      vim.fn.slice(all_jumps, 0, last_jump),
      vim.fn.reverse(vim.fn.slice(all_jumps, last_jump)),
    })
    local filtered_jumps = vim.fn.filter(sorted_jumps, function(_, j)
      return j.bufnr ~= bufnr and vim.fn.buflisted(j.bufnr) == 1
    end)
    local jump = filtered_jumps[#filtered_jumps]

    -- 位置 P が存在しない場合は `:bprev` で代用する
    if jump == nil then
      vim.cmd.bprev()
      return
    end

    -- 位置 P に移動する
    vim.api.nvim_win_set_buf(winid, jump.bufnr)
    vim.fn.winrestview(vim.tbl_deep_extend('force', jump, {
      curswant = jump.col,
    }))
  end)

  -- 閉じる対象のバッファを開いている全てのウィンドウで別のバッファへの移動を行った
  -- これにより bdelete を実行してもウィンドウは閉じなくなる
  local closed, err = pcall(vim.cmd.bdelete, { args = { bufnr }, bang = bang })

  -- 閉じることができなかった場合、元々の view を復元する
  if not closed then
    runallwin(function(winid)
      vim.api.nvim_win_set_buf(winid, bufnr)
      vim.fn.winrestview(views[winid])
    end)
    error(err, 0)
  end
end
```

## 解説
ほとんどの説明はコメントで行っているので、ここでは位置 P について詳述します
ここで言う位置 P とは「jumplist の現在位置の直後、もしくは直前」を指しています
つまり、`^O` を何回か押下したあとの位置 P は、そのときに `^I` を押下して移動する位置となります (`^I` が失敗した場合は更に `^O` で移動する位置)

```lua
local all_jumps, last_jump = unpack(vim.fn.getjumplist(winnr))

-- 位置 P を導出する
local sorted_jumps = vim.fn.flatten({
  vim.fn.slice(all_jumps, 0, last_jump),
  vim.fn.reverse(vim.fn.slice(all_jumps, last_jump)),
})
local filtered_jumps = vim.fn.filter(sorted_jumps, function(_, j)
  return j.bufnr ~= bufnr and vim.fn.buflisted(j.bufnr) == 1
end)
local jump = filtered_jumps[#filtered_jumps]
```

位置 P の導出部では、まず全ての jumplist エントリを、現在位置より未来方向のものを全て逆順に並び換えています
これによって、`{ ^O m 回目 (最も過去の jump), , , ^O 2 回目, ^O 1 回目, ^I n 回目 (最も未来の jump), , , ^I 2 回目, ^I 1 回目 }` のように並んだ配列が得られます
これを更に閉じる対象の bufnr でフィルタすることで、バッファを閉じたあとの位置 P が配列の末尾に来ます
こうすることで、(私が) 直感的に直前だと感じる位置に遷移することができます

## 使用例
`<leader>b*` に各引数が入ったものを割り当てています

```lua
for _, entry in pairs({
  { key = 'd', desc = '現在のバッファを閉じる', write = false, bang = false, winclose = false },
  { key = 'D', desc = '現在のバッファをウィンドウごと閉じる', write = false, bang = false, winclose = true },
  { key = 'z', desc = '現在のバッファを保存して閉じる', write = true, bang = false, winclose = false },
  { key = 'Z', desc = '現在のバッファを保存してウィンドウごと閉じる', write = true, bang = false, winclose = true },
  { key = 'q', desc = '現在のバッファを保存せずに閉じる', write = false, bang = true, winclose = false },
  { key = 'Q', desc = '現在のバッファを保存せずにウィンドウごと閉じる', write = false, bang = true, winclose = true },
}) do
  vim.keymap.set('n', '<leader>b' .. entry.key, function()
    bd(entry.write, entry.bang, entry.winclose)
  end, { desc = entry.desc })
end
```

## おわりに
git の commit や rebase 時に nvim のタブが開くようにしているので、`<leader>bZ` や `<leader>bQ` は非常によく使ってます

また、`位置 P` については下記のような動きをするときのために作成しました
- 前提: git 管理されている `.env-template` ファイルと、.gitignore に書かれている `.env` ファイルがある。ファジーファインダーのファイル検索では ignore されているファイルが出ない設定になっている
1. ファジーファインダーで `.env-template` を開く
1. ファイラで同階層の `.env` を開く
1. `^O` で `.env-template` に戻る
1. `<leader>bd` でバッファを閉じる

`:bdelete` では期待する `.env` ではなく良く分からない位置に飛ばされるので、自作した関数をとても便利に感じています
