vim9script

# 入力モードや変換候補を表示するポップアップウィンドウ

import './const.vim' as C
import './util.vim' as U
import './jisyo.vim' as J
const Contains = U.Contains

export var winid = 0
export var winpos: dict<any> = { col: 0, line: 0 }
export var cands: list<string>  = []
export var src = ''
export var yomi = ''
export var okuri = ''
export var index = -1
export var selected = ''
export var shortcut = []

def Create()
  if U.IsPopupExists(winid)
    return
  endif
  winid = popup_create('', {
    hidden: true,
    tabpage: -1,
    maxheight: g:vim9skkp.popup_maxheight,
    zindex: g:vim9skkp.zindex,
    wrap: false,
  })
enddef

export def Close()
  if !!winid
    popup_close(winid)
    winid = 0
  endif
enddef

export def FollowCursor(p: dict<any>, text: string)
  const a = &lines - p.line < C.bot_margin ? -1 : 1
  winpos = {
    col: p.col + (!cands ? strdisplaywidth(text) : 0),
    line: p.line + a,
    pos: a < 0 ? 'botleft' : 'topleft',
  }
  popup_move(winid, winpos)
enddef

export def Show()
  if !cands
    ShowMode()
  else
    ShowCands()
  endif
  if mode() ==# 'c'
    redraw
  endif
enddef

def ShowMode()
  Create()
  UnSelect()
  if g:vim9skkp_status.midasi
    popup_settext(winid, g:vim9skkp.mode_label.midasi)
  else
    popup_settext(winid, g:vim9skkp_status.mode)
  endif
  popup_show(winid)
enddef

export def ShowCands(text: string = '')
  Create()
  if !!text
    src = text
    [cands, yomi, okuri] = J.GetAllCands(text)
  endif
  if !cands
    return
  endif
  shortcut = U.ToList(g:vim9skkp.keymap.shortcut)
  var i = 0
  var lines = []
  for k in cands
    const l = k->substitute(';', "\t", '')
    const s = get(shortcut, i, '')
    if !s
      lines += [l]
    else
      lines += [$'{s}:{l}']
    endif
    i += 1
  endfor
  popup_settext(winid, lines)
  win_execute(winid, 'setlocal tabstop=12')
  win_execute(winid, 'syntax match PMenuExtra /\t.*/')
  win_execute(winid, 'syntax match PMenuKind /^.*:/')
  popup_show(winid)
  if !!text
    popup_setoptions(winid, { cursorline: true })
    Select(0)
  endif
enddef

export def ShowRecentAndHistory(text: string)
  src = text
  cands = J.GetRecentAndHistory(text)
  UnSelect()
  Show()
enddef

def Select(i: number)
  const c = len(cands) - 1
  index = i < 0 ? c : c < i ? 0 : i
  selected = cands[index]->matchstr('^[^;]\+') .. okuri
  win_execute(winid, $':{index + 1}')
  popup_setoptions(winid, { cursorline: true })
  doautocmd User vim9skkp-s-select
enddef

export def UnSelect()
  index = -1
  selected = ''
  popup_setoptions(winid, { cursorline: false })
enddef

export def Reset()
  cands = []
  okuri = ''
  UnSelect()
enddef

def ShortCut(key: string): bool
  const i = shortcut->index(key)
  if cands->len() - 1 < i
    return false
  endif
  Select(i)
  doautocmd User vim9skkp-s-commit
  return true
enddef

export def Filter(key: string, _: bool): bool
  if cands->empty()
    return false
  elseif U.IsBackSpace(key)
    Reset()
    return false
  elseif g:vim9skkp.keymap.select->Contains(key) && index !=# -1
    Select(index + 1)
  elseif g:vim9skkp.keymap.next->Contains(key)
    Select(index + 1)
  elseif g:vim9skkp.keymap.prev->Contains(key)
    Select(index - 1)
  elseif shortcut->Contains(key)
    return ShortCut(key)
  elseif g:vim9skkp.keymap.commit->Contains(key)
    doautocmd User vim9skkp-s-commit
  elseif g:vim9skkp.keymap.cancel->Contains(key)
    doautocmd User vim9skkp-s-cancel
  elseif g:vim9skkp.keymap.delete->Contains(key)
    cands = J.DeleteCand(cands, cands[index])
    if !cands
      doautocmd User vim9skkp-s-cancel
    else
      Select(index)
    endif
  else
    return false
  endif
  return true
enddef

