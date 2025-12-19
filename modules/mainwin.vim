vim9script

# 文字入力ポップアップウィンドウ

import './const.vim' as C
import './util.vim' as U
import './jisyo.vim' as J
import './keyhook.vim' as K

const Tr = U.Tr
const Contains = U.Contains

export var winid = 0
export var active = false
export var text = ''
export var chartype = C.Type.Hira
export var midasi = false
export var sticky_shift = false
var prevent_redraw = false

# 表示制御 {{{
export def Popup()
  if !U.IsPopupExists(winid)
    winid = popup_create('', { zindex: g:vim9skkp.zindex })
  endif
  win_execute(winid, 'syntax match Vim9skkp /./')
  win_execute(winid, 'syntax match Vim9skkpCursor /.$/')
  chartype = C.Type.Hira
  midasi = g:vim9skkp.keep_midasi_mode
  SetText('')
  active = true
enddef

export def Close()
  popup_close(winid)
  winid = 0
  active = false
  redraw
enddef

# textが空の場合はカーソル位置の文字を空かしておく
def ShowCharAtCursor()
  if prevent_redraw
    return
  endif
  popup_settext(winid, U.GetCharAtCursor() ?? ' ')
enddef

export def FollowCursor(p: dict<any>)
  if prevent_redraw
    return
  endif
  popup_move(winid, p)
  if !text
    ShowCharAtCursor()
  endif
enddef

export def SetText(_text: string)
  if text ==# _text
    return
  endif
  text = _text
  RedrawText()
  doautocmd User vim9skkp-m-settext
enddef

def RedrawText()
  if prevent_redraw
    return
  endif
  if !text
    ShowCharAtCursor()
  else
    # textの末尾にカーソルを表示
    popup_settext(winid, text .. ' ')
  endif
enddef

# ちらつき防止
def SetRedrawAfterFeedKeys()
  timer_start(1, (_) => {
    prevent_redraw = false
    const c = g:vim9skkp.getcurpos(U.GetCurPos())
    FollowCursor(c)
    RedrawText()
  })
enddef
# }}}

# キー入力制御 {{{

# 入力制御の大枠
export def Filter(key: string, mapping: bool): bool
  const done = FilterImpl(key, mapping)
  if done
    SetStickyShift(false)
    return true
  elseif !mapping
    # マッピング後のキーをkeyhook#Filterから貰うため一旦falseで返す
    return false
  endif

  # マッピング後のキーでもやることが無かった場合
  SetStickyShift(false)
  if !!text
    Commit(key)
    return true
  else
    return false
  endif
enddef

# 入力制御のメイン
def FilterImpl(_key: string, mapping: bool): bool
  var key = _key
  if sticky_shift
    key = key->toupper()
  endif
  if C.arrows->Contains(key)
    # NOTE: 入力が入ったままカーソル移動されると面倒だが、
    # コマンドモードではカーソル移動したいので入力が空のときは矢印キーを許可する
    return mapping && !!text
  elseif U.IsBackSpace(key)
    return BackSpace(mapping)
  endif

  if CommitBeforeInput(key, mapping)
    return false
  endif

  # 文字入力
  const is_normal_char = key ==# ' ' || key ==# key->keytrans()
  if chartype.roman && is_normal_char
    ProcessMidasi(key)
    const newtext = InputRoman(key)
    if newtext !=# text
      SetText(newtext)
      if !midasi && text !~ '[っッ][a-z]$'
        Commit()
      endif
      AfterAddChar()
      return true
    endif
  endif
  if StartSelect(key)
    return true
  elseif InputAlphabet(key, mapping)
    return mapping
  endif
  if CommonFunctions(key)
    return true
  elseif mapping && is_normal_char
    $'{text}{key->tolower()}'->SetText()
    AfterAddChar()
    return true
  endif
  return false
enddef

def AfterAddChar()
  if text =~ g:vim9skkp.auto_commit_regex
    Commit()
  endif
  if !!g:vim9skkp.auto_suggest_regex &&
      text =~ g:vim9skkp.auto_suggest_regex
    StartSelect()
  endif
enddef

def SetStickyShift(b: bool)
  if sticky_shift !=# b
    sticky_shift = b
    doautocmd User Vim9skkpStatusChanged
  endif
enddef

def CommonFunctions(key: string): bool
  if g:vim9skkp.keymap.toggle->Contains(key)
    doautocmd User vim9skkp-m-toggle
    return true
  elseif g:vim9skkp.keymap.cancel->Contains(key)
    doautocmd User vim9skkp-m-cancel
    return true
  elseif g:vim9skkp.keymap.midasi->Contains(key)
    Commit()
    SetMidasiMode(!midasi)
    return true
  elseif g:vim9skkp.keymap.sticky_shift->Contains(key)
    SetStickyShift(true)
    return true
  elseif g:vim9skkp.keymap.userjisyo->Contains(key)
    doautocmd User vim9skkp-userjisyo
    return true
  elseif ChangeCharType(key)
    doautocmd User Vim9skkpStatusChanged
    return true
  elseif !!text &&
    (midasi || chartype ==# C.Type.Abbr) &&
    g:vim9skkp.keymap.commit->Contains(key)
    Commit()
    return true
  else
    return false
  endif
enddef

def BackSpace(mapping: bool): bool
  if mapping || !text
    return false
  endif
  text
    ->substitute('.$', '', '')
    ->SetText()
  return true
enddef

# 文字入力前に項目が選択されていた場合などは確定する
# Filterの処理を中断するならtrueを返す
def CommitBeforeInput(key: string, mapping: bool): bool
  if !text || !mapping
    # NOP
  elseif midasi && key ==# J.prefix
    Commit()
  elseif g:vim9skkp_status.is_cand_selected
    if key ==# "\<ESC>"
      # ノーマルモードに戻るパターン
      return true
    else
      Commit()
    endif
  endif
  return false
enddef

def InputAlphabet(key: string, mapping: bool): bool
  if C.abbr_chars->index(key) ==# -1
    return false
  elseif !mapping
    return true
  elseif chartype ==# C.Type.Abbr
    SetText(text .. key)
    return true
  elseif chartype ==# C.Type.Alph
    SetText(text .. key->Tr(C.abbr_chars, C.alphabet_chars))
    Commit()
    return true
  else
    return false
  endif
enddef

def ToKata(s: string, ct: C.Type): string
  const hira = s
    ->Tr(C.kata_chars, C.hira_chars)
    ->Tr(C.hankaku_chars, C.hira_chars)
  if ct ==# C.Type.Kata
    return hira->Tr(C.hira_chars, C.kata_chars)
  elseif ct ==# C.Type.Hank
    return hira->Tr(C.hira_chars, C.hankaku_chars)
  elseif ct ==# C.Type.Hira
    return hira
  else
    return s
  endif
enddef

export def SetMidasiMode(b: bool)
  if midasi !=# b
    midasi = b
    silent! doautocmd User Vim9skkpStatusChanged
  endif
enddef

def ProcessMidasi(key: string): bool
  if key !~ '[A-Z]' ||
      text->stridx(g:vim9skkp.marker_okuri) !=# -1
    return false
  endif
  const m = midasi && !!text ? g:vim9skkp.marker_okuri : ''
  SetMidasiMode(true)
  text
    ->substitute('n$', chartype.n, '')
    ->substitute('$', m, '')
    ->SetText()
  return true
enddef

def InputRoman(key: string): string
  const lower = key->tolower()
  const newtext = text .. lower
  const l = len(newtext)
  for k in C.roman_keys
    const i = l - len(k)
    if i < 0
      continue
    endif
    if newtext->strpart(i) !=# k
      continue
    endif
    const r = repeat('.', len(k))
    var v = ToKata(C.roman_table[k], chartype)
    if !v
      # NOTE: roman_tableの値に空文字を指定して無効にした場合
      continue
    endif
    return newtext
      ->substitute($'n{r}$', $'{chartype.n}{r}', '')
      ->substitute($'{r}$', v, '')
  endfor
  return text
enddef

def ChangeCharType(key: string): bool
  const oldtype = chartype
  for ct in C.Type.values
    if g:vim9skkp.keymap[ct.label]->Contains(key)
      if midasi && !!text
        const before = text
        text
          ->substitute($'n$', $'{chartype.n}', '')
          ->ToKata(ct)
          ->SetText()
        J.AddRecent(before, text)
        Commit()
        return true
      else
        noautocmd SetMidasiMode(false)
        noautocmd ToggleCharType(ct)
      endif
      break
    endif
  endfor
  return oldtype !=# chartype
enddef

export def ToggleCharType(ct: C.Type)
  if chartype ==# ct
    chartype = C.Type.Hira
  else
    chartype = ct
  endif
  silent! doautocmd User Vim9skkpStatusChanged
enddef

export def Commit(key: string = '')
  if midasi && chartype ==# C.Type.Hira
    text = text->substitute(g:vim9skkp.marker_okuri, '', 'n')
  endif
  prevent_redraw = true
  SetRedrawAfterFeedKeys()
  J.AddHistory(text)
  K.FeedKeys($'{text}{key}', !!key)
  SetText('')
  if chartype ==# C.Type.Abbr
    ToggleCharType(C.Type.Abbr)
    midasi = g:vim9skkp.keep_midasi_mode
  endif
  SetMidasiMode(g:vim9skkp.keep_midasi_mode && midasi)
  doautocmd User vim9skkp-m-commit
enddef

def StartSelect(key: string = ''): bool
  if !text
    return false
  elseif g:vim9skkp_status.is_cand_selected
    return false
  elseif !midasi && chartype !=# C.Type.Abbr
    return false
  elseif !!key && !g:vim9skkp.keymap.select->Contains(key)
    return false
  endif
  text
    ->substitute('n$', chartype.n, '')
    ->SetText()
  doautocmd User vim9skkp-m-start
  return true
enddef
# }}}

