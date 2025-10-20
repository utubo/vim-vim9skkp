vim9script

# 各ポップアップウィンドウの統括
# 要はmainwin.vimとsubwin.vimの橋渡し

import './const.vim' as C
import './util.vim' as U
import './mainwin.vim' as M
import './subwin.vim' as S
import './keyhook.vim' as K
import './jisyo.vim' as J
import './userjisyo.vim' as UJ

var initialized = false
var timerForCheckPopupExists = 0
var bak = { t_ve: '', gcr: '' }

# 初期化 {{{
def Init()
  if initialized
    return
  endif
  C.roman_table = C.roman_table_base->extend(g:vim9skkp.roman_table)
  C.roman_keys = C.roman_table->keys()->sort((a, b) => len(b) - len(a))
  C.roman_chars = C.roman_keys->join()->split('\zs')
  for [k, v] in C.roman_table->items()
    C.okuri_table[v->strcharpart(0, 1)] = k[0]
  endfor
  SetupAutocmd()
  initialized = true
enddef
# }}}

# 表示制御 {{{
# ポップアップウィンドウを表示する
export def Popup()
  Init()
  StopCheckPopupExists()
  M.Popup()
  S.Show()
  K.SetupKeyHook()
  J.ReadyHistory()
  timerForCheckPopupExists = timer_start(
    C.update_interval,
    CheckPopupExists,
    { repeat: -1 }
  )
  FollowCursor()
  HideCursor()
  redraw
  doautocmd User Vim9skkpStatusChanged
enddef

# ポップアップウィンドウをカーソル付近に追従させる
# NOTE: CursorMovedIやCursorMovedCで実行すると<C-r>=foo<CR>などのマッピングでチラつく
def FollowCursor()
  if M.active
    const c = g:vim9skkp.getcurpos(U.GetCurPos())
    M.FollowCursor(c)
    S.FollowCursor(c, M.text)
  endif
enddef

# <C-c>などでポップアップが閉じられた場合に終了させる
def StopCheckPopupExists()
  if !!timerForCheckPopupExists
    timer_stop(timerForCheckPopupExists)
    timerForCheckPopupExists = 0
  endif
enddef

def CheckPopupExists(_: number)
  if !M.active
    doautocmd User vim9skkp-abort
  elseif !U.IsPopupExists(M.winid)
    doautocmd User vim9skkp-abort
  elseif !U.IsPopupExists(S.winid)
    doautocmd User vim9skkp-abort
  else
    FollowCursor()
  endif
enddef
# }}}

# イベント制御 {{{
def SetupAutocmd()
  augroup vim9skkp
    au!
    au ModeChanged *:[nt] Close()

    # mainwinが発行するイベント
    au User vim9skkp-m-toggle Toggle()
    au User vim9skkp-m-settext OnSetText()
    au User vim9skkp-m-before-add-char {
      if S.index !=# -1
        M.Commit()
      endif
    }
    au User vim9skkp-m-start {
      if S.index ==# -1
        M.PreStart()
        S.ShowCands(M.text)
        if len(S.cands) < 2 && get(S.cands, 0, ';無変換') =~ ';無変換'
          UJ.RegisterWithInstant(S.yomi)
        endif
      endif
    }
    au User vim9skkp-m-commit {
      if M.active
        S.Reset()
        S.cands = J.GetHistory()
        S.Show()
        FollowCursor()
        if mode() ==# 'c'
          redraw
        endif
      endif
    }
    au User vim9skkp-m-cancel {
      if !M.text
        Close()
      else
        M.SetText('')
      endif
    }

    # subwinが発行するイベント
    au User vim9skkp-s-select M.SetText(S.selected)
    au User vim9skkp-s-commit {
      J.AddRecent(S.src, S.cands[S.index])
      J.AddHistory(S.selected)
      M.Commit()
    }
    au User vim9skkp-s-cancel {
      M.SetText(S.src)
      S.Reset()
      S.Show()
    }

    # global
    au User Vim9skkpStatusChanged {
      g:vim9skkp_status.active = M.active
      if M.active
        g:vim9skkp_status.midasi = M.midasi && M.chartype !=# C.Type.Abbr
        g:vim9skkp_status.mode = g:vim9skkp.mode_label[M.chartype.label]
        g:vim9skkp_status.sticky_shift = M.sticky_shift
        S.Show()
      else
        g:vim9skkp_status.midasi = false
        g:vim9skkp_status.mode = g:vim9skkp.mode_label.off
        g:vim9skkp_status.sticky_shift = false
      endif
    }
    au User vim9skkp-abort {
      try
        Close()
      catch
        g:vim9skkp_exception = v:exception
      endtry
    }
  augroup END
enddef

def OnSetText()
  if !M.active
    return
  endif
  if S.index ==# -1 && M.midasi
    S.ShowRecentAndHistory(M.text)
  else
    S.Show()
  endif
  FollowCursor()
  redraw
enddef
# }}}

# SKKオンオフ {{{
export def Close()
  StopCheckPopupExists()
  M.SetText('')
  M.Close()
  S.Reset()
  S.Close()
  RestoreCursor()
  doautocmd User Vim9skkpStatusChanged
  redraw
enddef

def HideCursor()
  if !g:vim9skkp.hide_cursor
    hi! link Vim9skkpCursorAct Vim9skkpCursor
    return
  endif
  if !bak.t_ve
    bak.t_ve = &t_ve
    set t_ve=
  endif
  if !bak.gcr
    bak.gcr = &guicursor
    set guicursor=i-c:CursorTransparent
  endif
enddef

def RestoreCursor()
  if !!bak.t_ve
    &t_ve = bak.t_ve
    bak.t_ve = ''
  endif
  if !!bak.gcr
    &guicursor = bak.gcr
    bak.gcr = ''
  endif
enddef

export def Toggle()
  if !M.active
    Popup()
    return
  endif
  M.Commit()
  if M.chartype !=# C.Type.Hira
    M.ToggleCharType(C.Type.Hira)
    redraw
  elseif M.midasi && !g:vim9skkp.keep_midasi_mode
    M.SetMidasiMode(false)
    redraw
  else
    Close()
  endif
enddef
# }}}

