# 🧩vim9skkp
vim9skkp は、SKK日本語入力をVim9 scriptとポップアップウインドウで実装した実験的なプラグインです

ポップアップウインドウで頑張ることで以下を実現しています

- 確定するまでバッファが汚れない
- キー入力はポップアップのフィルターで処理するのでマッピング自体は上書き等されない(有効、無効、トグルはさすがにマップしますが)

## 注意
- 絶賛作成中です
- 🐞だらけです
- 当面、破壊的変更がしょっちゅう入ります(特に設定まわり)

### 最近の破壊的変更
  - `keep_midasi_mode`->`sticky_lock`へ名前変更
  - `showmode`->`mode_display`へ名前変更
  - `keymap.midasi`を削除。

## インストール

辞書をダウンロードする
```bash
cd ~
wget http://openlab.jp/skk/dic/SKK-JISYO.L.gz
gunzip -f SKK-JISYO.L.gz
```

お好きな方法でvimにvim9skkpを読み込ませる  
(以下はpack以下に置いて読み込ませる例)
```bash
cd ~/.vim/pack/foo/start
git clone https://github.com/utubo/vim-vim9skkp.git
```

## 設定とか

[doc/vim9skkp.txt](doc/vim9skkp.txt)

### おすすめ設定

個人的には以下の設定をしてます

```vimscript
g:vim9skkp = {
  sticky_lock: false,
}
```

## 既知の問題

cmdlineが折り返され画面全体が押し上げられた場合表示がずれます

