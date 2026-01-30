vim9script

import '../modules/popup/core.vim' as Core
import '../modules/skk/jisyo.vim' as J
import '../modules/skk/userjisyo.vim' as UJ
import '../modules/key/keyhook.vim' as K
import '../modules/common/settings.vim' as SS

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
  SS.Initialize() # NOTE: g:vim9skkpを読みこみ
  autocmd CmdlineEnter * ++once Enable()
  const value = input(g:vim9skkp.terminal_prompt)->trim()
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

