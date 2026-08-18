vim9script

# 入力モードや変換候補を表示するポップアップウィンドウ

import '../common/const.vim' as C
import '../common/util.vim' as U
import '../skk/jisyo.vim' as J
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

const POPUP_TYPE_CLOSED = 0
const POPUP_TYPE_MODE = 1
const POPUP_TYPE_CANDS = 2
var popup_type = POPUP_TYPE_CLOSED
var default_options = {
  hidden: true,
  tabpage: -1,
  maxheight: C.default_maxheight,
  zindex: C.default_zindex,
  wrap: false,
}

def Create(pt: number)
  if popup_type !=# pt
    Close()
  endif
  if U.IsPopupExists(winid)
    return
  endif
  const opt = {}
    ->extend(default_options)
    ->extend(pt ==# POPUP_TYPE_MODE ?
    { highlight: 'Vim9skkpMode' } :
    { highlight: 'Vim9skkpCand' })
    ->extend(pt ==# POPUP_TYPE_MODE ?
    g:vim9skkp.mode_popup_options :
    g:vim9skkp.cands_popup_options)
    ->extend(winpos)
  winid = popup_create('', opt)
  popup_type = pt
enddef

export def Close()
  if !!winid
    popup_close(winid)
    winid = 0
    g:vim9skkp_status.cand_winid = 0
    popup_type = POPUP_TYPE_CLOSED
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

export def OnMoved()
  popup_show(winid)
  if mode() ==# 'c'
    redraw
  endif
enddef

export def Show()
  if !cands
    ShowMode()
  else
    ShowCands()
  endif
enddef

def ShowMode()
  Create(POPUP_TYPE_MODE)
  UnSelect()
  if g:vim9skkp.mode_display !=# 'popup'
    popup_hide(winid)
    return
  endif
  popup_settext(winid, g:vim9skkp_status.mode_label)
  g:vim9skkp_status.cand_winid = 0
  silent! doautocmd User vim9skkp-s-show
enddef

export def ShowCands(text: string = '', src_roman: string = '')
  Create(POPUP_TYPE_CANDS)
  if !!text
    src = text
    [cands, yomi, okuri] = J.GetAllCands(text, src_roman)
  endif
  if !cands
    return
  endif
  shortcut = U.ToList(g:vim9skkp.keymap.shortcut)
  var idx = 0
  var lines = []
  for k in cands
    const s = get(shortcut, idx, '')->keytrans()
    var [c, d] = U.Split(k, ';')
    if !!s
      c = $'{s}:{c}'
    endif
    if !d
      lines += [c]
    else
      const p = $"{repeat(' ', C.cand_width - strdisplaywidth(c))}\t"
      lines += [$'{c}{p}{d}']
    endif
    idx += 1
  endfor
  popup_settext(winid, lines)
  popup_setoptions(winid, {
    highlight: 'Vim9skkpCand',
    title: g:vim9skkp.cands_popup_options->get('title', '')
  })
  win_execute(winid, 'setlocal tabstop=1')
  win_execute(winid, 'syntax match Vim9skkpCandExtra /\t\zs.*/')
  win_execute(winid, 'syntax match Vim9skkpCandShortCut /^.*:/')
  g:vim9skkp_status.cand_winid = winid
  silent! doautocmd User vim9skkp-s-show
  silent! doautocmd User Vim9skkpCandPopup

  if !!text
    popup_setoptions(winid, { cursorline: true })
    Select(0)
  endif
enddef

export def ShowAsPredict()
  UnSelect()
  Show()
  if !!cands
    popup_setoptions(winid, { title: g:vim9skkp.predict_title })
  endif
enddef

def Select(idx: number)
  const c = len(cands) - 1
  index = idx < 0 ? c : c < idx ? 0 : idx
  selected = cands[index]->matchstr('^[^;]\+') .. okuri
  g:vim9skkp_status.is_cand_selected = true
  win_execute(winid, $':{index + 1}')
  popup_setoptions(winid, { cursorline: true })
  doautocmd User vim9skkp-s-select
enddef

export def UnSelect()
  index = -1
  selected = ''
  g:vim9skkp_status.is_cand_selected = false
  popup_setoptions(winid, { cursorline: false })
enddef

export def Reset()
  cands = []
  yomi = ''
  okuri = ''
  UnSelect()
enddef

def ShortCut(key: string): bool
  const idx = shortcut->index(key)
  if cands->len() - 1 < idx
    return false
  endif
  Select(idx)
  doautocmd User vim9skkp-s-commit
  return true
enddef

def SelectByTag(tag: string): bool
  const chars = - strchars(tag)
  const idx = cands->indexof((_, v) => v[chars : -1] ==# tag)
  g:a = cands
  if idx !=# -1
    Select(idx)
    doautocmd User vim9skkp-s-commit
  endif
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
  elseif g:vim9skkp.keymap.select_kata->Contains(key)
    return SelectByTag(J.tag_kata)
  elseif g:vim9skkp.keymap.select_direct->Contains(key)
    return SelectByTag(J.tag_direct)
  elseif g:vim9skkp.keymap.select_upper->Contains(key)
    return SelectByTag(J.tag_upper)
  elseif g:vim9skkp.keymap.select_lower->Contains(key)
    return SelectByTag(J.tag_lower)
  elseif g:vim9skkp.keymap.commit->Contains(key)
    if index < 0
      return false
    endif
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
  elseif g:vim9skkp.keymap.userjisyo->Contains(key)
    doautocmd User vim9skkp-userjisyo
  elseif g:vim9skkp.keymap.kata->Contains(key)
    doautocmd User vim9skkp-s-chartype
    return false
  elseif g:vim9skkp.keymap.hankaku->Contains(key)
    doautocmd User vim9skkp-s-chartype
    return false
  else
    return false
  endif
  return true
enddef

