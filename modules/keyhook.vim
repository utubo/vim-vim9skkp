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
  elseif mapping
    return MappedFilter(key)
  else
    return NoMappedFilter(key)
  endif
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

# TODO: 最初のころはM.NoMappedFilterとM.MappedFilterで中身が結構違ったけど
# 今はほぼ同じなのでこの2つのメソッドは分けなくてもいいかな…？

def NoMappedFilter(key: string): bool
  if S.NoMappedFilter(key)
    return true
  elseif M.NoMappedFilter(key)
    return true
  else
    # 一旦mapping: trueにしてマッピング済みの入力を受け入れる
    popup_setoptions(M.winid, { mapping: true })
    mapping = true
    feedkeys(key, 'i')
    return true
  endif
enddef

def MappedFilter(key: string): bool
  popup_setoptions(M.winid, { mapping: false })
  mapping = false
  if S.MappedFilter(key)
    return true
  elseif M.MappedFilter(key)
    return true
  else
    return false
  endif
enddef

