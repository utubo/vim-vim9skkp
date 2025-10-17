vim9script

# ユーザー辞書登録のプロンプト

import './jisyo.vim' as J
import './mainwin.vim' as M
import './subwin.vim' as S
import './core.vim' as Core # TODO: 相互参照になってる

var registerToUserJisyo = false
var winid = 0
var yomi = ''

# 読みを入力するプロンプト
export def InputYomi(is_instant: bool): string
  if registerToUserJisyo
    return ''
  endif
  if is_instant
    return yomi
  endif
  registerToUserJisyo = true
  var value = ''
  try
    feedkeys("\<Cmd>call vim9skkp#Enable()\<CR>")
    value = input('ユーザー辞書に登録(読み): ')->trim()
  finally
    registerToUserJisyo = false
  endtry
  return value
enddef

# 変換後を入力するプロンプト
export def Register(_yomi: string, is_instant: bool): string
  var value = ''
  try
    feedkeys("\<Cmd>call vim9skkp#Enable()\<CR>")
    value = input($'ユーザー辞書に登録({_yomi}): ')->trim()
  finally
    if !value
      echo 'キャンセルしました'
    else
      const r = J.AddUserWord(_yomi, value)
      echo r ? '登録しました' : '登録済みです'
    endif
    if is_instant
      EndOfInstant(value)
    endif
  endtry
  return value
enddef

# 変換候補が無かった時にインスタントに呼び出す用
export def RegisterWithInstant(_yomi: string)
  if registerToUserJisyo
    return
  endif
  winid = 0
  if mode() ==# 'i'
    var p = popup_getpos(M.winid)
    winid = popup_create(M.text, {
      col: p.col, line: p.line, highlight: 'Vim9skkpBlur'
    })
  endif
  S.Reset()
  yomi = _yomi
  # NOTE: なぜかfeedkeysからcallで呼び出すとfilterが機能する…
  feedkeys("\<Cmd>call vim9skkp#RegisterToUserJisyo('', v:true)\<CR>")
enddef

# インスタントに呼び出した場合
# ・辞書登録したら変換を確定する
# ・登録しなかったら元の状態に戻す
def EndOfInstant(value: string)
  if !!winid
    popup_close(winid)
    winid = 0
  endif
  Core.Popup()
  M.SetText(value ?? yomi)
  if !value
    M.SetMidasiMode(true)
  else
    M.Commit()
  endif
enddef

