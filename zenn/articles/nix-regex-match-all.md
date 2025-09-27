---
title: "Nix lang で regex matchAll する"
emoji: "🗒"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["nix"]
published: false
---

## はじめに

Nix lang の builtins には正規表現で文字列マッチを行える `match` 関数が存在します

```nix
builtins.match ''^.*<([^>]+)>.*$'' ''a<b>c''
# [ "b" ]
```

ただ、マッチする全ての文字列を取得することは恐らくできません

```nix
# match は文字列全体にマッチするパターンを与える必要があるため
# 括弧とその中身にのみマッチするようには書けない
builtins.match ''^.*(<([^>]+)>.*)+$'' ''a<b>c<d>e''
# [ "<d>e" "d" ]
```

「文字列の括弧の中身を全て取り出したい」というときは、`match` の代わりに `split` を使うことができます

## `builtins.split`

`split` はパターンで文字列を分割する関数です

```nix
builtins.split '','' "a,b,c"
# [ "a" [ ] "b" [ ] "c" ]
```

このように、分割された文字列と list が交互に入った list が返ってきます
中の list にはパターンのグループが入るので、

```nix
builtins.split ''<([^>]+)>'' ''a<b>c<d>e''
# [ "a" [ "b" ] "c" [ "d" ] "e" ]
```

このようにすることで list の中に全てのマッチ結果を入れることができます

## 使用例
複数の URL が含まれる文字列 (今回は https://nixos.org/ を使用) から、良い感じの attribute set の list を作ります

:::message
真面目に URL をパースするのは辛いので仕様に則したパターンは作れていません
:::

```nix
with builtins; let
  source = readFile (fetchurl "https://nixos.org/");
  availableChars = ''-a-zA-Z0-9\._~!#%\$&'\(\)\*\+,:;=\?@'';
  pattern = ''(([a-z]+)://([${availableChars}]+)/?([${availableChars}/]+)?)'';
  splitted = split pattern source;
  groups = filter (e: typeOf e == "list") splitted;
  sets =
    map (group: {
      href = builtins.elemAt group 0;
      protocol = builtins.elemAt group 1;
      host = builtins.elemAt group 2;
      path = builtins.elemAt group 3;
    })
    groups;
in
  sets;
# [
#   {
#     href = "https://nixos.org/";
#     protocol = "https";
#     host = "nixos.org";
#     path = null;
#   }
#   {
#     href = "https://survey.nixos.org/759934";
#     protocol = "https";
#     host = "survey.nixos.org";
#     path = "759934";
#   }
#   {
#     href = "http://www.w3.org/2000/svg";
#     protocol = "http";
#     host = "www.w3.org";
#     path = "2000/svg";
#   }
#   ...
```
