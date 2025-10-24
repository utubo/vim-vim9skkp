# 🧩vim9skkp
vim9skkp は、SKK日本語入力をVim9 scriptとポップアップウインドウで実装した実験的なプラグインです

ポップアップウインドウで頑張ることで以下を実現しています

- 確定するまでバッファが汚れない
- キーマッピングの上書きを最低限に(特にメリットは無いですが…)

絶賛作成中です  
🐞だらけだと思います！  
当面、破壊的変更がしょっちゅう入ります(特に設定まわり)

## 設定とか

[doc/vim9skkp.txt](doc/vim9skkp.txt)

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

## おすすめ設定

個人的には以下の設定をしてます

```vimscript
g:vim9skkp = {
  keep_midasi_mode: false,
}
```

## 既知の問題

tabpanelが左に表示されているとコマンドラインで表示がずれます  
プラグインでは対応できないのでtabpanelを右に表示するなどしてください

