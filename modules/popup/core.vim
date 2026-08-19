vim9script

# 各ポップアップウィンドウの統括
# 要はpopup/main.vimとpopup/sub.vimの橋渡し

import '../common/const.vim' as C
import '../common/util.vim' as U
import '../popup/main.vim' as M
import '../popup/sub.vim' as S
import '../key/keyhook.vim' as K
import '../skk/jisyo.vim' as J
import '../skk/userjisyo.vim' as UJ
import '../common/settings.vim' as SS

var timerForCheckPopupExists = 0
var prevent_redraw = false
var bak = { t_ve: '', gcr: '' }

# 初期化 {{{
def Init()
  const initialized = get(g:, 'vim9skkp', {})->get('initialized', SS.none)
  if initialized < SS.marged
    SS.Initialize()
  endif
  if initialized < SS.initialized
    C.roman_table = C.roman_table_base->extend(g:vim9skkp.roman_table)
    C.roman_keys = C.roman_table->keys()->sort((a, b) => len(b) - len(a))
    C.roman_chars = C.roman_keys->join()->split('\zs')->uniq()
    g:vim9skkp.jisyo = J.ExpandPaths(g:vim9skkp.jisyo)
    SetupAutocmd()
  endif
  g:vim9skkp.initialized = SS.initialized
enddef
# }}}

# 表示制御 {{{
# ポップアップウィンドウを表示する
export def Popup()
  if pumvisible()
    K.FeedKeys("\<C-y>", false)
  endif
  Init()
  StopCheckPopupExists()
  prevent_redraw = true
  M.Popup()
  S.Popup()
  K.SetupKeyHook(M.winid, [S.Filter, M.Filter])
  J.ReadyHistory()
  timerForCheckPopupExists = timer_start(
    C.update_interval,
    CheckPopupExists,
    { repeat: -1 }
  )
  HideCursor()
  ClosePumLazy()
  augroup vim9skkp-cursormoved
    au! CursorMovedI,CursorMovedC * U.Silent(QueueRedraw)
  augroup END
  Redraw() # NOTE: ここでウィンドウ位置を調整しておかないとチラつく
  prevent_redraw = false
  doautocmd User Vim9skkpStatusChanged
enddef

def ClosePumLazy()
  # NOTE: pumvisible()～feedkeys()の間で何かの処理をしている間に
  # pumが消えると<C-e>が暴発するので、できるだけ間を置かず実行する
  timer_start(0, (_) => {
    if pumvisible()
      K.FeedKeys("\<C-e>", false)
    endif
  })
enddef

# <C-c>などでポップアップが閉じられた場合に終了させる
def CheckPopupExists(_: number)
  U.Silent(CheckPopupExistsImpl)
enddef

def CheckPopupExistsImpl()
  if !M.active
    Abort()
  elseif !U.IsPopupExists(M.winid)
    Abort()
  elseif !U.IsPopupExists(S.winid)
    Abort()
  elseif mode() ==# 'n'
    # noautocmd normal! "\<Esc>"
    # とかされると有効のままノーマルモードになってしまうので…
    Abort()
  endif
enddef

def StopCheckPopupExists()
  if !!timerForCheckPopupExists
    timer_stop(timerForCheckPopupExists)
    timerForCheckPopupExists = 0
  endif
enddef

# ちらつき防止
var redraw_timer = 0
def QueueRedraw(_: number = 0)
  if prevent_redraw
    return
  endif
  if !!redraw_timer
    timer_stop(redraw_timer)
  endif
  redraw_timer = timer_start(1, (_) => {
    Redraw()
    redraw_timer = 0
  })
enddef

def Redraw(_: number = 0)
  if !M.active
    return
  endif
  const c = g:vim9skkp.getcurpos(U.GetCurPos())
  M.Redraw(c)
  S.FollowCursor(c, M.text)
  redraw
  # TODO: 2回redrawしないとmode_display = 'cursor'でカタカナ入力が即時表示されない？
  if g:vim9skkp.mode_display ==# 'cursor'
    redraw
  endif
enddef
# }}}

# イベント制御 {{{
def SetupAutocmd()
  augroup vim9skkp
    au!
    # mainwinが発行するイベント
    au User vim9skkp-m-toggle Toggle()
    au User vim9skkp-m-settext OnSetText()
    au User vim9skkp-m-start {
      S.PopupCands(M.text, M.src_roman->join(''))
      if len(S.cands) < 2 && get(S.cands, 0, J.tag_muhen) =~ J.tag_muhen
        M.SetText(S.src)
        UJ.RegisterWithInstant()
      endif
    }
    au User vim9skkp-m-commit {
      if M.active
        S.Reset()
        if g:vim9skkp.predict
          S.cands = J.GetHistory()
          S.PopupAsPredict()
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
    au User vim9skkp-s-select {
      M.SetText(S.selected)
    }
    au User vim9skkp-s-commit {
      J.AddRecent(S.src, S.cands[S.index])
      M.Commit()
    }
    au User vim9skkp-s-cancel {
      M.SetText(S.src)
      S.Reset()
      S.Popup()
    }
    au User vim9skkp-s-chartype {
      M.SetText(S.src)
      S.Reset()
    }
    au User vim9skkp-s-show {
      if !redraw_timer
        S.Show()
      endif
      QueueRedraw()
    }

    # global
    au ModeChanged *:[nt] U.Silent(Close)
    au User Vim9skkpStatusChanged {
      g:vim9skkp_status.active = M.active
      if M.active
        g:vim9skkp_status.midasi = M.midasi && M.chartype !=# C.Type.Abbr
        g:vim9skkp_status.mode = g:vim9skkp.mode_label[M.chartype.label]
        g:vim9skkp_status.sticky_shift = M.sticky_shift
      else
        g:vim9skkp_status.midasi = false
        g:vim9skkp_status.mode = g:vim9skkp.mode_label.off
        g:vim9skkp_status.sticky_shift = false
      endif
      g:vim9skkp_status.mode_label = g:vim9skkp_status.midasi
        ? g:vim9skkp.mode_label.midasi
        : g:vim9skkp_status.mode
      if M.active && !redraw_timer
        M.Redraw()
        S.Popup()
      endif
    }
    au User vim9skkp-queueredraw QueueRedraw()
    au User vim9skkp-lockredraw prevent_redraw = true
    au User vim9skkp-unlockredraw prevent_redraw = false

    # ショートカットキーでユーザー辞書登録を起動したとき
    au User vim9skkp-userjisyo {
      const src = S.src ?? M.text
      if !src
        K.FeedKeys("\<Cmd>Vim9skkpRegisterToUserJisyo\<CR>", true)
      else
        M.SetText(src)
        UJ.RegisterWithInstant()
      endif
    }
  augroup END
enddef

def OnSetText()
  if !M.active
    return
  endif
  if S.index ==# -1 && M.midasi && g:vim9skkp.predict
    S.src = M.text
    S.cands = J.GetRecentAndHistory(M.text)
    S.PopupAsPredict()
  else
    S.Popup()
  endif
  if !M.text
    ClosePumLazy()
  endif
  QueueRedraw()
  redraw
enddef
# }}}

# SKKオンオフ {{{
export def Close()
  au! vim9skkp-cursormoved
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
  bak.t_ve = bak.t_ve ?? &t_ve
  bak.gcr = bak.gcr ?? &guicursor
  set t_ve=
  set guicursor=i-c:CursorTransparent
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
    M.ResetMidasiModeAndStickyShift(g:vim9skkp.sticky_lock)
    redraw
  elseif M.midasi && !g:vim9skkp.sticky_lock
    M.ResetMidasiModeAndStickyShift(false)
    redraw
  else
    Close()
  endif
enddef

# 不意にポップアップがクローズされた場合
def Abort()
  U.Silent(Close)
enddef
# }}}

