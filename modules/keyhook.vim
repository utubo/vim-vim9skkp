vim9script

# <Space>等が他のプラグインの影響を受けやすいので
# mapping: falseとmapping: trueの両方でキー入力を受け取るよう頑張る
# とか面倒なことはここで吸収する

import './mainwin.vim' as M
import './subwin.vim' as S

export var enable = true

var mapping = false
var ctrlr = false
var dump = []

export def SetupKeyHook(_: number = 0)
  popup_setoptions(M.winid, {
    mapping: false,
    filter: Filter,
    filtermode: 'ic',
  })
  mapping = false
  ctrlr = false
enddef

def Filter(_: number, key: string): bool
  Dump(key)
  if key ==# "\<CursorHold>"
    return false
  elseif !enable
    return false
  elseif M.AddQueue(key)
    return true
  elseif ctrlr
    return false
  elseif CtrlR(key)
    return false
  endif

  # マッピング済みの入力を受け取ったらポップアップのmappingを元に戻しておく
  const m = mapping
  if m
    popup_setoptions(M.winid, { mapping: false })
    mapping = false
  endif

  # キー処理メイン
  if S.Filter(key, m)
    return true
  elseif M.Filter(key, m)
    return true
  elseif m || state('m') ==# 'm'
    return false
  else
    # 一旦mapping: trueにしてマッピング済みの入力をFilterで受けなおす
    popup_setoptions(M.winid, { mapping: true })
    mapping = true
    feedkeys(key, 'i')
  endif

  return true
enddef

def CtrlR(key: string): bool
  if key ==# "\<C-r>" || key ==# "\<Cmd>" || key ==# "\<ScriptCmd>"
    ctrlr = true
    timer_start(0, (_) => {
      ctrlr = false
    })
    return true
  else
    return false
  endif
enddef

def Dump(key: string)
  if !g:vim9skkp.dumpsize
    return
  endif
  dump->add({
    key: key, enable: enable, mapping: mapping, ctrlr: ctrlr,
  })
  const offset = len(dump) - g:vim9skkp.dumpsize
  if 0 < offset
    dump->remove(0, offset)
  endif
enddef

export def ShowDump()
  for d in dump
    echo $'key:{d.key} {char2nr(d.key)} enable:{d.enable} mapping:{d.mapping} ctrlr:{d.ctrlr}'
  endfor
enddef

