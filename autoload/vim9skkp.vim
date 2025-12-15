vim9script

import '../modules/const.vim' as C
import '../modules/core.vim' as Core
import '../modules/jisyo.vim' as J
import '../modules/userjisyo.vim' as UJ
import '../modules/subwin.vim' as S
import '../modules/keyhook.vim' as K

# API {{{
export def Enable()
  Core.Popup()
enddef

export def Disable()
  Core.Close()
enddef

export def Toggle()
  Core.Toggle()
enddef

export def Nop(a: any): any
  return a
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

export def Dump()
  K.ShowDump()
enddef
# }}}

# Plugin local {{{
export def SetKeyHookState(state: number)
  K.state = state
enddef
# }}}

