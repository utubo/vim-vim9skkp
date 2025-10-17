vim9script

# <Space>等が他のプラグインの影響を受けやすいので
# mapping: falseとmapping: trueの両方でキー入力を受け取るよう頑張る
# とか面倒なことはここで吸収する

import './mainwin.vim' as M
import './subwin.vim' as S

var mapping = false
var ctrlr = false

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
  if key ==# "\<CursorHold>"
    return false
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
  elseif m
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
    timer_start(10, (_) => {
      ctrlr = false
    })
    return true
  else
    return false
  endif
enddef

