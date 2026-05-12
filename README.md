# ✏️vim9skkp

<img width="659" height="316" alt="image" src="https://github.com/user-attachments/assets/042b833c-a843-4473-aec2-ad7c70a80d68" />

vim9skkp は、SKK日本語入力をVim9 scriptとポップアップウインドウで実装した実験的なプラグインです

ポップアップウインドウで頑張ることで以下を実現しています

- 確定するまでバッファが汚れない
- キー入力はポップアップのフィルターで処理するのでキーマッピングはほぼ上書きされない(有効、無効、トグルはさすがにマップしますが)

## 注意
- 絶賛作成中です
- 🐞だらけです
- 当面、破壊的変更がしょっちゅう入ります(特に設定まわり)

### 最近の破壊的変更
  - 設定: `maxheight`, `zindex`を削除、代わりに`cands_popup_options`などを追加
  - 設定名: `recent`->`recent_limit`へ名前変更
  - イベント: `Vim9skkpInitializePost`と`Vim9skkpInitializePost`を削除
  - 設定名: `keep_midasi_mode`->`sticky_lock`へ名前変更
  - 設定名: `showmode`->`mode_display`へ名前変更
  - 設定名: `keymap.midasi`を削除。

## インストール

辞書をダウンロードする
```bash
cd ~
wget http://openlab.jp/skk/dic/SKK-JISYO.L.gz
gunzip -f SKK-JISYO.L.gz
```

お好きな方法でVimにvim9skkpを読み込ませる  
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

