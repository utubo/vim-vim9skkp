vim9script

import '../modules/const.vim' as C
import '../modules/core.vim' as Core
import '../modules/jisyo.vim' as J
import '../modules/userjisyo.vim' as UJ
import '../modules/subwin.vim' as S

export def Enable()
  Core.Popup()
enddef

export def Disable()
  Core.Close()
enddef

export def Toggle()
  Core.Toggle()
enddef

export def RefreshCands()
  S.Show()
enddef

export def NoChangeCurPos(popup_pos: any): any
  return popup_pos
enddef

export def TerminalInput()
  autocmd CmdlineEnter * ++once Enable()
  const value = input($'terminalに入力: ')->trim()
  if !!value
    feedkeys(value, 'int')
  endif
enddef

export def RefreshJisyo()
  J.RefreshJisyo()
enddef

export def RegisterToUserJisyo(_yomi: string = '', is_instant: bool = false)
  const yomi = _yomi ?? UJ.InputYomi(is_instant)
  if !!yomi
    UJ.Register(yomi, is_instant)
  endif
enddef
